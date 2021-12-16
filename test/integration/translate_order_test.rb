# frozen_string_literal: true
# typed: true

require_relative '../test_helper'

class Critic::OrderTranslation < Critic::FunctionalTest
  before do
    @user = make_user(save: true)
  end

  def standalone_item_id
    '01t5e000002bEQTAA2'
  end

  def default_pricebook_id
    '01s5e00000BAoBWAA1'
  end

  def create_salesforce_order(sf_product_id: nil, additional_order_fields: {})
    # https://github.com/sseixas/CPQ-JS

    # TODO pull these dynamically
    sf_product_id ||= '01t5e000003DsarAAC'
    pricebook_id = default_pricebook_id

    account_id = sf.create!('Account', Name: "REST Customer #{DateTime.now}")
    opportunity_id = sf.create!('Opportunity', {Name: "REST Oppt #{DateTime.now}", "CloseDate": DateTime.now.iso8601, AccountId: account_id, StageName: "Closed/Won"})
    contact_id = sf.create!('Contact', {LastName: 'Bianco', Email: 'mbianco@stripe.com'})

    # you can create a quote without *any* fields, which seems completely silly
    quote_id = sf.create!(CPQ_QUOTE, {
      "SBQQ__Opportunity2__c": opportunity_id,
      CPQ_QUOTE_PRIMARY => true,
      'SBQQ__PrimaryContact__c' => contact_id,
      'SBQQ__PricebookId__c' => pricebook_id,
    }.merge(additional_order_fields))

    # https://developer.salesforce.com/docs/atlas.en-us.cpq_api_dev.meta/cpq_api_dev/cpq_api_read_quote.htm
    # get CPQ version of the quote
    cpq_quote_representation = JSON.parse(sf.get("services/apexrest/SBQQ/ServiceRouter?reader=SBQQ.QuoteAPI.QuoteReader&uid=#{quote_id}").body)

    cpq_product_representation = JSON.parse(sf.patch("services/apexrest/SBQQ/ServiceRouter?loader=SBQQ.ProductAPI.ProductLoader&uid=#{sf_product_id}", {
      context: {
        # productId: product_id,
        pricebookId: pricebook_id,
        # currencyCode:
      }.to_json,
    }).body)

    # https://gist.github.com/paustint/bd18bd281134a180e014829b49ed043a
    quote_with_product = JSON.parse(sf.patch('/services/apexrest/SBQQ/ServiceRouter?loader=SBQQ.QuoteAPI.QuoteProductAdder', {
      context: {
        "quote": cpq_quote_representation,
        "products": [
          cpq_product_representation,
        ],
        "groupKey": 0,
        "ignoreCalculate": true,
        # quote: {
        #   record: {
        #     Id: quote_id,
        #     attributes: {
        #       type: CPQ_QUOTE,
        #     }
        #   }
        # },
        # products: [
        #   {
        #     record: {
        #       Id: product_id
        #     }
        #   }
        # ],
        # ignoreCalculate: true
      }.to_json,
    }).body)

    # calculated_quote = JSON.parse(sf.patch('/services/apexrest/SBQQ/ServiceRouter?loader=SBQQ.QuoteAPI.QuoteCalculator', {
    #   "context": { "quote": updated_quote["record"] }.to_json
    # }).body)


    # https://developer.salesforce.com/docs/atlas.en-us.cpq_dev_api.meta/cpq_dev_api/cpq_quote_api_calculate_final.htm
    calculated_quote = JSON.parse(sf.patch('/services/apexrest/SBQQ/ServiceRouter?loader=SBQQ.QuoteAPI.QuoteCalculator', {
      # "context": quote_with_product.to_json
      # "context": saved_quote.to_json
      # "context": sf.get("services/apexrest/SBQQ/ServiceRouter?reader=SBQQ.QuoteAPI.QuoteReader&uid=#{quote_id}").body
      "context": {"quote" => quote_with_product}.to_json,
    }).body)

    # https://developer.salesforce.com/docs/atlas.en-us.cpq_dev_api.meta/cpq_dev_api/cpq_quote_api_save_final.htm
    saved_quote = JSON.parse(sf.post('/services/apexrest/SBQQ/ServiceRouter', {
      "saver": "SBQQ.QuoteAPI.QuoteSaver",
      "model": calculated_quote.to_json,
    }).body)

    # sf.create!(CPQ_QUOTE_LINE, {
    #   CPQ_QUOTE => quote_id,
    #   CPQ_QUOTE_LINE_PRODUCT => product_id,
    #   CPQ_QUOTE_LINE_PRICEBOOK_ENTRY => pricebook_entry_id
    # })

    # give CPQ some time to calculate...
    # sleep(5)

    # it looks like there is additional field validation triggered here when `ordered` is set to true
    sf.update!(CPQ_QUOTE, 'Id' => quote_id, CPQ_QUOTE_ORDERED => true)

    sf_quote = sf.find(CPQ_QUOTE, quote_id)

    # https://salesforce.stackexchange.com/questions/251904/get-sales-order-line-on-rest-api
    # TODO note that looking in the UI is the easiest way to get these magic relational values
    related_orders = sf.get("/services/data/v52.0/sobjects/#{CPQ_QUOTE}/#{quote_id}/SBQQ__Orders__r")
    sf_order = related_orders.body.first

    sf.update!('Order', 'Id' => sf_order.Id, 'Status' => 'Activated')

    # TODO need refresh here
    sf.find('Order', sf_order.Id)

    # contract_id = salesforce_client.create!('Contract', accountId: account_id)
    # order_id = salesforce_client.create!('Order', {Status: "Draft", EffectiveDate: "2021-09-21", AccountId: account_id, ContractId: contract_id})
  end

  it 'integrates a subscription order' do
    price_in_dollars = 240
    sf_product_id = create_salesforce_product
    sf_pricebook_entry_id = create_salesforce_price(sf_product_id: sf_product_id, price: price_in_dollars)

    sf_order = create_salesforce_order(
      sf_product_id: sf_product_id,

      additional_order_fields: {
        CPQ_QUOTE_SUBSCRIPTION_START_DATE => "2021-10-01",
        CPQ_QUOTE_SUBSCRIPTION_TERM => 12.0,
      }
    )

    SalesforceTranslateRecordJob.translate(@user, sf_order)

    # TODO add refresh to library
    sf_order = sf.find('Order', sf_order.Id)

    stripe_id = sf_order[ORDER_STRIPE_ID]
    subscription_schedule = Stripe::SubscriptionSchedule.retrieve(stripe_id, @user.stripe_credentials)
    customer = Stripe::Customer.retrieve(T.cast(subscription_schedule.customer, String), @user.stripe_credentials)
    # line = subscription.items.first

    # TODO customer address assertions once mapping is complete

    invoices = Stripe::Invoice.list({subscription: subscription_schedule.subscription}, @user.stripe_credentials)

    assert_equal(1, invoices.count)
    invoice = invoices.first

    # should be two lines since we are backdating the invoice
    assert_equal(2, invoice.lines.count)

    line = invoice.lines.data[-1]
    assert_equal(1, line.quantity)
    assert_equal(price_in_dollars, line.amount / 100.0)

    # right now, price translation is tied to both a pricebook and order line in SF
    # test the price translation logic here right now instead of in a separate price test
    price = line.price
    assert_equal(price_in_dollars, price.unit_amount / 100)
    assert_equal("recurring", price.type)
    assert_equal("month", price.recurring.interval)
    assert_equal(1, price.recurring.interval_count)
    assert_equal("licensed", price.recurring.usage_type)
  end

  describe 'failures' do
    it 'gracefully fails when the subscription term and start date does not exist' do
      sf_order = create_salesforce_order

      assert_raises(Integrations::Errors::MissingRequiredFields) do
        SalesforceTranslateRecordJob.translate(@user, sf_order)
      end

      # TODO assert on specific fields which are missing
      # TODO assert on custom object in SF
    end
  end

  # TODO multiple quantity
  # TODO quantity as float
  # TODO start date in the future
  # TODO missing fields / failure
  # TODO subscription term specified

  it 'integrates a invoice order' do
    sf_order = create_salesforce_order(sf_product_id: standalone_item_id)

    SalesforceTranslateRecordJob.translate(@user, sf_order)

    # TODO add refresh to library
    sf_order = sf.find('Order', sf_order.Id)

    stripe_id = sf_order[ORDER_STRIPE_ID]
    invoice = Stripe::Invoice.retrieve(stripe_id, @user.stripe_credentials)
    customer = Stripe::Customer.retrieve(invoice.customer, @user.stripe_credentials)
    line = invoice.lines.first

    puts sf_order.Id
  end
end
