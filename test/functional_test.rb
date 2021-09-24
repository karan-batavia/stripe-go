require "minitest/autorun"
require 'pry-rescue/minitest'
require_relative '../config'

Bundler.require(:default, :development, :test)

class FunctionalTests < MiniTest::Spec
  include StripeForce::Constants

  before do
    @user = StripeForce::User.new(
      salesforce_token: ENV.fetch('SF_ACCESS_TOKEN'),
      salesforce_refresh_token: ENV.fetch('SF_REFRESH_TOKEN'),
      salesforce_instance_url: "https://#{ENV.fetch('SF_INSTANCE')}.my.salesforce.com",
    )
  end

  def sf
    @user.sf_client
  end

  def create_salesforce_order
    # https://github.com/sseixas/CPQ-JS

    # TODO pull these dynamically
    product_id = '01t5e000003DsarAAC'
    pricebook_entry_id = '01u5e000000jGn6AAE'
    pricebook_id = '01s5e00000BAoBVAA1'

    account_id = sf.create!('Account', Name: "REST Customer #{DateTime.now}")
    opportunity_id = sf.create!('Opportunity', {Name: "REST Oppt #{DateTime.now}", "CloseDate": DateTime.now.iso8601, AccountId: account_id, StageName: "Closed/Won"})
    contact_id = sf.create!('Contact', {LastName: 'Bianco', Email: 'mbianco@stripe.com'})

    # you can create a quote without *any* fields, which seems completely silly
    quote_id = sf.create!(CPQ_QUOTE, {
      "SBQQ__Opportunity2__c": opportunity_id,
      CPQ_QUOTE_PRIMARY => true,
      'SBQQ__PrimaryContact__c' => contact_id,
      'SBQQ__PricebookId__c' => pricebook_id
    })

    # https://developer.salesforce.com/docs/atlas.en-us.cpq_api_dev.meta/cpq_api_dev/cpq_api_read_quote.htm
    # get CPQ version of the quote
    cpq_quote_representation = JSON.parse(sf.get("services/apexrest/SBQQ/ServiceRouter?reader=SBQQ.QuoteAPI.QuoteReader&uid=#{quote_id}").body)

    cpq_product_representation = JSON.parse(sf.patch("services/apexrest/SBQQ/ServiceRouter?loader=SBQQ.ProductAPI.ProductLoader&uid=#{product_id}", {
      context: {
        # productId: product_id,
        pricebookId: pricebook_id,
        # currencyCode:
      }.to_json
    }).body)

    # https://gist.github.com/paustint/bd18bd281134a180e014829b49ed043a
    quote_with_product = JSON.parse(sf.patch('/services/apexrest/SBQQ/ServiceRouter?loader=SBQQ.QuoteAPI.QuoteProductAdder', {
      context: {
          "quote": cpq_quote_representation,
          "products": [
            cpq_product_representation
          ],
          "groupKey": 0,
          "ignoreCalculate": true
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
      "context": { "quote" => quote_with_product }.to_json
    }).body)

    # https://developer.salesforce.com/docs/atlas.en-us.cpq_dev_api.meta/cpq_dev_api/cpq_quote_api_save_final.htm
    saved_quote = JSON.parse(sf.post('/services/apexrest/SBQQ/ServiceRouter', {
      "saver": "SBQQ.QuoteAPI.QuoteSaver",
      "model": calculated_quote.to_json
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
    sf_order = create_salesforce_order

    StripeForce::Translate.perform(user: @user, sf_object: sf_order)

    # TODO add refresh to library
    sf_order = sf.find('Order', sf_order.Id)

    stripe_id = sf_order[ORDER_STRIPE_ID]
    subscription = Stripe::Subscription.retrieve(stripe_id, @user.stripe_credentials)
    customer = Stripe::Customer.retrieve(subscription.customer, @user.stripe_credentials)
    line = subscription.items.first
  end

  it 'integrates a invoice order' do

  end
end

def example_sf_order
  # sf.find('Order', '8015e000000IJ1rAAG')

  # order with recurring item
  # sf.find('Order', '8015e000000IJDxAAO')

  sf.find('Order', '8015e000000IJF5AAO')
end
