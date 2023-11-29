# frozen_string_literal: true
# typed: true

require_relative './_lib'

class Critic::OrderAmendmentTermination < Critic::OrderAmendmentFunctionalTest
  before do
    set_cassette_dir(__FILE__)
    if !VCR.current_cassette.originally_recorded_at.nil?
      Timecop.freeze(VCR.current_cassette.originally_recorded_at)
    end

    @user = make_user(save: true)
    @user.enable_feature(FeatureFlags::TERMINATION_METADATA)
  end

  # assumes monthly subscription
  def create_amendment_and_adjust_quantity(sf_contract:, quantity:)
    amendment_data = create_quote_data_from_contract_amendment(sf_contract)
    assert_equal(1, amendment_data["lineItems"].count)

    # first amendment cannot start on the same date, must add one
    amendment_count = 1 + sf.query(
      <<~EOL
        SELECT COUNT() FROM #{SF_ORDER}
        WHERE Opportunity.SBQQ__AmendedContract__c = '#{sf_contract.Id}'
      EOL
    ).count


    amendment_data["lineItems"].first["record"][CPQ_QUOTE_QUANTITY] += quantity
    amendment_data["record"][CPQ_QUOTE_SUBSCRIPTION_START_DATE] = format_date_for_salesforce(now_time + amendment_count.month)
    amendment_data["record"][CPQ_QUOTE_SUBSCRIPTION_TERM] = 12 - amendment_count

    sf_order = create_order_from_quote_data(amendment_data)
    create_contract_from_order(sf_order)
    sf_order
  end

  it 'cancels a subscription in the future' do
    # initial subscription: quantity 1
    # order amendment: quantity 0
    # one phase with a shortened end date

    sf_order = create_subscription_order(contact_email: "cancel_sub_future")
    StripeForce::Translate.perform_inline(@user, sf_order.Id)

    sf_contract = create_contract_from_order(sf_order)
    # api precondition: initial orders have a nil contract ID
    sf_order.refresh
    assert_nil(sf_order.ContractId)

    # the contract should reference the initial order that was created
    assert_equal(sf_order[SF_ID], sf_contract[SF_CONTRACT_ORDER_ID])

    amendment_end_date = now_time + 9.months
    amendment_data = create_quote_data_from_contract_amendment(sf_contract)
    # wipe out the product
    amendment_data["lineItems"].first["record"][CPQ_QUOTE_QUANTITY] = 0
    amendment_data["record"][CPQ_QUOTE_SUBSCRIPTION_START_DATE] = format_date_for_salesforce(amendment_end_date)
    amendment_data["record"][CPQ_QUOTE_SUBSCRIPTION_TERM] = 3

    sf_order_amendment = create_order_from_quote_data(amendment_data)
    assert_equal(sf_order_amendment.Type, OrderTypeOptions::AMENDMENT.serialize)

    StripeForce::Translate.perform_inline(@user, sf_order_amendment.Id)

    sf_order.refresh
    stripe_id = sf_order[prefixed_stripe_field(GENERIC_STRIPE_ID)]

    subscription_schedule = Stripe::SubscriptionSchedule.retrieve(stripe_id, @user.stripe_credentials)
    assert_equal(1, subscription_schedule.phases.count)

    # make sure the end date is modified to match the end date of the amendment
    phase = T.must(subscription_schedule.phases.first)
    assert_equal(0, amendment_end_date.to_i - phase.end_date)
    assert_equal(0, phase.start_date - now_time.to_i)

    assert_equal(1, phase.items.count)
    assert_equal(0, phase.add_invoice_items.count)
    phase_item = T.must(phase.items.first)
    assert_equal(1, phase_item.quantity)

    original_subscription_schedule = Stripe::SubscriptionSchedule.retrieve(stripe_id, @user.stripe_credentials)
    original_subscription_phase = T.must(original_subscription_schedule.phases.first)
    excluded_comparison_fields = %i{metadata end_date}
    assert_equal(
      original_subscription_phase.to_hash.reject {|k, _v| excluded_comparison_fields.include?(k) },
      phase.to_hash.reject {|k, _v| excluded_comparison_fields.include?(k) },
      "outside of metadata and end_date the original subscription and terminated subscription should be equal"
    )
  end

  # stripe allows for zero-quantity line items, we need to make sure they are removed
  it 'removes a line item that is partially terminated' do
    # initial order: two lines
    # amendment order: removes one of the lines
    # resulting last sub phase: should have a single item
    @user.field_mappings = {
      "subscription_item" => {
        "sbc_termination.metadata.salesforce_effective_termination_date" => "OrderId.OpportunityId.CloseDate",
      },
    }
    @user.field_defaults = {
      "subscription_item" => {
        "sbc_termination.metadata.custom_metadata_field" => "custom_metadata_field_value",
      },
    }
    @user.save

    initial_start_date = now_time
    amendment_start_date = initial_start_date + 1.month
    standard_term = 12

    sf_product_id_1, sf_pricebook_id_1 = salesforce_recurring_product_with_price
    sf_product_id_2, _sf_pricebook_id_2 = salesforce_recurring_product_with_price
    sf_account_id = create_salesforce_account

    quote_id = create_salesforce_quote(
      sf_account_id: sf_account_id,
      contact_email: "remove_line_item_part_term_1",
      additional_quote_fields: {
        CPQ_QUOTE_SUBSCRIPTION_START_DATE => now_time_formatted_for_salesforce,
        CPQ_QUOTE_SUBSCRIPTION_TERM => TEST_DEFAULT_CONTRACT_TERM,
      }
    )

    quote_with_product = add_product_to_cpq_quote(quote_id, sf_product_id: sf_product_id_1)
    calculate_and_save_cpq_quote(quote_with_product)

    quote_with_product = add_product_to_cpq_quote(quote_id, sf_product_id: sf_product_id_2)
    calculate_and_save_cpq_quote(quote_with_product)

    sf_order = create_order_from_cpq_quote(quote_id)

    sf_contract = create_contract_from_order(sf_order)
    amendment_data = create_quote_data_from_contract_amendment(sf_contract)

    # remove the second product
    amendment_data["lineItems"].detect {|i| i["record"]["SBQQ__Product__c"] == sf_product_id_2 }["record"][CPQ_QUOTE_QUANTITY] = 0
    amendment_data["record"][CPQ_QUOTE_SUBSCRIPTION_START_DATE] = format_date_for_salesforce(amendment_start_date)
    amendment_data["record"][CPQ_QUOTE_SUBSCRIPTION_TERM] = standard_term - 1
    sf_order_partial_termination = create_order_from_quote_data(amendment_data)

    StripeForce::Translate.perform_inline(@user, sf_order_partial_termination.Id)
    sf_order.refresh

    stripe_id = sf_order[prefixed_stripe_field(GENERIC_STRIPE_ID)]
    subscription_schedule = Stripe::SubscriptionSchedule.retrieve(stripe_id, @user.stripe_credentials)

    assert_equal(2, subscription_schedule.phases.count)
    first_phase = T.must(subscription_schedule.phases.first)
    second_phase = T.must(subscription_schedule.phases[1])

    assert_equal(2, first_phase.items.count)
    assert_equal(1, second_phase.items.count)

    # only one item since the other was terminated
    second_phase_item = T.must(second_phase.items.first)
    assert_equal(1, second_phase_item.quantity)

    price = Stripe::Price.retrieve(T.cast(second_phase_item.price, String), @user.stripe_credentials)
    assert_equal(sf_pricebook_id_1, price.metadata['salesforce_pricebook_entry_id'])

    # confirm first phase item terminate metadata was added
    terminated_item = first_phase.items.detect {|i| i.price != second_phase_item.price }
    assert_equal("custom_metadata_field_value", T.must(terminated_item).metadata["custom_metadata_field"])
    assert_equal(StripeForce::Utilities::SalesforceUtil.get_effective_termination_date(@user, sf_order_partial_termination),
      T.must(terminated_item).metadata[StripeForce::Translate::Metadata.metadata_key(@user, MetadataKeys::EFFECTIVE_TERMINATION_DATE)])
  end

  # use case: user decides *right* after signing the contract they want to change their order competely
  it 'cancels a subscription on the same day it started' do
    @user.field_mappings = {
      "subscription_item" => {
        "sbc_termination.metadata.salesforce_effective_termination_date" => "OrderId.OpportunityId.CloseDate",
      },
      "subscription_schedule" => {
        "sbc_termination.metadata.salesforce_effective_termination_date" => "OpportunityId.CloseDate",
      },
    }
    @user.field_defaults = {
      "subscription_schedule" => {
        "sbc_termination.metadata.custom_metadata_field" => "custom_metadata_field_value",
      },
    }
    @user.save

    sf_order = create_subscription_order(contact_email: "cancel_sub_same_day")

    StripeForce::Translate.perform_inline(@user, sf_order.Id)

    sf_contract = create_contract_from_order(sf_order)
    # the contract should reference the initial order that was created
    assert_equal(sf_order[SF_ID], sf_contract[SF_CONTRACT_ORDER_ID])

    amendment_data = create_quote_data_from_contract_amendment(sf_contract)
    # remove the product
    amendment_data["lineItems"].first["record"][CPQ_QUOTE_QUANTITY] = 0
    # the quote is generated by the contract CPQ API, so we need to set these fields manually
    # let's have the second phase start in 9mo
    amendment_data["record"][CPQ_QUOTE_SUBSCRIPTION_START_DATE] = now_time_formatted_for_salesforce
    amendment_data["record"][CPQ_QUOTE_SUBSCRIPTION_TERM] = TEST_DEFAULT_CONTRACT_TERM

    sf_order_amendment = create_order_from_quote_data(amendment_data)
    assert_equal(sf_order_amendment.Type, OrderTypeOptions::AMENDMENT.serialize)

    StripeForce::Translate.perform_inline(@user, sf_order_amendment.Id)
    sf_order.refresh
    stripe_id = sf_order[prefixed_stripe_field(GENERIC_STRIPE_ID)]
    subscription_schedule = Stripe::SubscriptionSchedule.retrieve(stripe_id, @user.stripe_credentials)

    assert_equal(1, subscription_schedule.phases.count)
    assert_equal('canceled', subscription_schedule.status)

    # confirm termination metadata was added to the terminated phase item
    terminated_item = T.must(subscription_schedule.phases.first).items.first
    effective_termination_date = StripeForce::Utilities::SalesforceUtil.get_effective_termination_date(@user, sf_order_amendment)
    assert_equal(effective_termination_date, T.must(terminated_item).metadata[StripeForce::Translate::Metadata.metadata_key(@user, MetadataKeys::EFFECTIVE_TERMINATION_DATE)])

    # confirm the termination metadata was added to the subscription schedule
    assert_equal("custom_metadata_field_value", T.must(subscription_schedule.phases.last).metadata["custom_metadata_field"])
    assert_equal(effective_termination_date, T.must(subscription_schedule.phases.last).metadata["salesforce_effective_termination_date"])
  end

  it 'fully terminates an order after multiple amendments, processed separately' do
    # ensure multiple `peform_inline` works the same as a batch
  end

  it 'fully terminates an order after multiple amendments' do
    # intial order: 1 product
    # second order: +1 quantity
    # third order: +1 quantity
    # fourth order: -3 quantity

    sf_order = create_subscription_order(contact_email: "full_term_multiple_amendments")
    sf_contract = create_contract_from_order(sf_order)

    amendment_1 = create_amendment_and_adjust_quantity(sf_contract: sf_contract, quantity: 1)
    amendment_2 = create_amendment_and_adjust_quantity(sf_contract: sf_contract, quantity: 1)
    amendment_3 = create_amendment_and_adjust_quantity(sf_contract: sf_contract, quantity: -3)

    # test our assumption of the SF CPQ API
    # the revised order product ID *always* references the initial order line it is modifying
    initial_order_lines = sf_get_related(sf_order, SF_ORDER_ITEM)
    assert_equal(1, initial_order_lines.count)
    initial_order_line = sf_get(initial_order_lines.first.Id)
    assert_equal(1, initial_order_line['SBQQ__OrderedQuantity__c'])

    amendment_1_lines = sf_get_related(amendment_1, SF_ORDER_ITEM)
    assert_equal(1, amendment_1_lines.count)
    amendment_1_line = sf_get(amendment_1_lines.first.Id)
    assert_equal(initial_order_line.Id, amendment_1_line[SF_ORDER_ITEM_REVISED_ORDER_PRODUCT])
    assert_equal(1, amendment_1_line['SBQQ__OrderedQuantity__c'])

    amendment_2_lines = sf_get_related(amendment_2, SF_ORDER_ITEM)
    assert_equal(1, amendment_2_lines.count)
    amendment_2_line = sf_get(amendment_2_lines.first.Id)
    assert_equal(initial_order_line.Id, amendment_2_line[SF_ORDER_ITEM_REVISED_ORDER_PRODUCT])
    assert_equal(1, amendment_2_line['SBQQ__OrderedQuantity__c'])

    # puts "Original Order Line"
    # puts "Amendment 1 Order Line:"
    # puts sf_get_related(amendment_1, SF_ORDER_ITEM).first.Id
    # puts "Amendment 2 Order Line:"
    # puts sf_get_related(amendment_2, SF_ORDER_ITEM).first.Id
    # puts "Amendment 3 Order Line (termination):"
    # puts sf_get_related(amendment_3, SF_ORDER_ITEM).first.Id

    # test contract structure logic to make sure the amendments are determined properly
    sf_order.refresh
    locker = Integrations::Locker.new(@user)
    translator = StripeForce::Translate.new(@user, locker)
    translator.cache_service.cache_for_object(sf_order)
    contract_structure = translator.extract_contract_from_order(sf_order)

    # the order of the amendments is important
    assert_equal(sf_order.Id, contract_structure.initial.Id)
    assert_equal(amendment_1.Id, contract_structure.amendments[0]&.Id)
    assert_equal(amendment_2.Id, contract_structure.amendments[1]&.Id)
    assert_equal(amendment_3.Id, contract_structure.amendments[2]&.Id)

    StripeForce::Translate.perform_inline(@user, sf_order.Id)

    sf_order.refresh
    stripe_id = sf_order[prefixed_stripe_field(GENERIC_STRIPE_ID)]
    subscription_schedule = Stripe::SubscriptionSchedule.retrieve({id: stripe_id, expand: %w{phases.items.price}}, @user.stripe_credentials)

    assert_equal(3, subscription_schedule.phases.count)
    last_phase = T.must(subscription_schedule.phases.last)
    assert((now_time + 3.months).to_i - last_phase.end_date < 1.hour)

    amendment_opportunity_close_date = sf_get(amendment_3["OpportunityId"])[SF_OPPORTUNITY_CLOSE_DATE]
    T.must(last_phase).items.each {|item| assert_equal(amendment_opportunity_close_date, item.metadata[StripeForce::Translate::Metadata.metadata_key(@user, MetadataKeys::EFFECTIVE_TERMINATION_DATE)]) }

    active_price = T.cast(subscription_schedule.phases.first&.items&.first&.price, Stripe::Price)
    assert(active_price.active)

    # assert active on prices
    all_items = StripeForce::Translate::OrderHelpers.extract_all_items_from_subscription_schedule(subscription_schedule).map(&:price)
    all_items = T.cast(all_items, T::Array[Stripe::Price])

    # all prices should be archived, if they aren't something is going wrong
    assert(all_items.reject {|p| p.id == active_price.id }.none?(&:active))
  end

  it 'partial termination of an original order' do
    # intial order: 1 product, quantity 50
    # second order: -49 quantity

    sf_product_id_1, _sf_pricebook_id_1 = salesforce_recurring_product_with_price
    sf_account_id = create_salesforce_account
    quote_id = create_salesforce_quote(sf_account_id: sf_account_id,
                                       contact_email: "partial_termination_amendment_1_0",
                                       additional_quote_fields: {
                                         CPQ_QUOTE_SUBSCRIPTION_START_DATE => now_time_formatted_for_salesforce,
                                         CPQ_QUOTE_SUBSCRIPTION_TERM => 12.0,
                                       })

    quote_with_product = add_product_to_cpq_quote(quote_id, sf_product_id: sf_product_id_1, product_quantity: 50)
    calculate_and_save_cpq_quote(quote_with_product)
    sf_order = create_order_from_cpq_quote(quote_id)
    SalesforceTranslateRecordJob.translate(@user, sf_order)

    # the revised order product ID *always* references the initial order line it is modifying
    initial_order_lines = sf_get_related(sf_order, SF_ORDER_ITEM)
    assert_equal(1, initial_order_lines.count)
    initial_order_line = sf_get(initial_order_lines.first.Id)
    assert_equal(50, initial_order_line['SBQQ__OrderedQuantity__c'])

    sf_contract = create_contract_from_order(sf_order)
    amendment_1 = create_amendment_and_adjust_quantity(sf_contract: sf_contract, quantity: -49)

    amendment_1_lines = sf_get_related(amendment_1, SF_ORDER_ITEM)
    assert_equal(1, amendment_1_lines.count)
    amendment_1_line = sf_get(amendment_1_lines.first.Id)
    assert_equal(initial_order_line.Id, amendment_1_line[SF_ORDER_ITEM_REVISED_ORDER_PRODUCT])
    assert_equal(-49, amendment_1_line['SBQQ__OrderedQuantity__c'])

    # test contract structure logic to make sure the amendments are determined properly
    sf_order.refresh
    locker = Integrations::Locker.new(@user)
    translator = StripeForce::Translate.new(@user, locker)
    translator.cache_service.cache_for_object(sf_order)
    StripeForce::Translate.perform_inline(@user, sf_order.Id)
    sf_order.refresh

    stripe_id = sf_order[prefixed_stripe_field(GENERIC_STRIPE_ID)]
    subscription_schedule = Stripe::SubscriptionSchedule.retrieve({id: stripe_id, expand: %w{phases.items.price}}, @user.stripe_credentials)
    assert_equal(2, subscription_schedule.phases.count)

    first_phase = T.must(subscription_schedule.phases[0])
    assert_equal(1, first_phase.items.count)
    assert_equal(50, T.must(first_phase.items.first).quantity)

    last_phase = T.must(subscription_schedule.phases.last)
    assert_equal(1, last_phase.items.count)
    assert_equal(1, T.must(last_phase.items.first).quantity)
  end

  it 'partial termination of an amendment order upgrade' do
    # intial order: 1 product, quantity 2
    # second order: same product, + 2 quantity
    # third order: same product, -1 quantity

    sf_product_id_1, _sf_pricebook_id_1 = salesforce_recurring_product_with_price
    sf_account_id = create_salesforce_account
    quote_id = create_salesforce_quote(sf_account_id: sf_account_id,
                                       contact_email: "partial_termination_of_upgrade_amendment_8",
                                       additional_quote_fields: {
                                         CPQ_QUOTE_SUBSCRIPTION_START_DATE => now_time_formatted_for_salesforce,
                                         CPQ_QUOTE_SUBSCRIPTION_TERM => 12.0,
                                       })

    quote_with_product = add_product_to_cpq_quote(quote_id, sf_product_id: sf_product_id_1, product_quantity: 2)
    calculate_and_save_cpq_quote(quote_with_product)
    sf_order = create_order_from_cpq_quote(quote_id)

    # the revised order product ID *always* references the initial order line it is modifying
    initial_order_lines = sf_get_related(sf_order, SF_ORDER_ITEM)
    assert_equal(1, initial_order_lines.count)
    initial_order_line = sf_get(initial_order_lines.first.Id)
    assert_equal(2, initial_order_line['SBQQ__OrderedQuantity__c'])

    # translate the initial order
    SalesforceTranslateRecordJob.translate(@user, sf_order)
    sf_order.refresh

    # create the upgrade amendment
    sf_contract = create_contract_from_order(sf_order)
    sf_order_amendment_1 = create_amendment_and_adjust_quantity(sf_contract: sf_contract, quantity: 3)

    # verify amendment lines
    amendment_1_lines = sf_get_related(sf_order_amendment_1, SF_ORDER_ITEM)
    assert_equal(1, amendment_1_lines.count)
    amendment_1_line = sf_get(amendment_1_lines.first.Id)
    assert_equal(initial_order_line.Id, amendment_1_line[SF_ORDER_ITEM_REVISED_ORDER_PRODUCT])
    assert_equal(3, amendment_1_line['SBQQ__OrderedQuantity__c'])
    sf_order_amendment_1.refresh

    # create the second amendment and increase quantity again (+1)
    sf_contract_2 = create_contract_from_order(sf_order_amendment_1)
    sf_order_amendment_2 = create_amendment_and_adjust_quantity(sf_contract: sf_contract_2, quantity: -1)

    amendment_2_lines = sf_get_related(sf_order_amendment_2, SF_ORDER_ITEM)
    assert_equal(1, amendment_2_lines.count)
    amendment_2_line = sf_get(amendment_2_lines.last.Id)
    assert_equal(-1, amendment_2_line['SBQQ__OrderedQuantity__c'])
    sf_order_amendment_2.refresh

    locker = Integrations::Locker.new(@user)
    translator = StripeForce::Translate.new(@user, locker)
    translator.cache_service.cache_for_object(sf_order)
    StripeForce::Translate.perform_inline(@user, sf_order_amendment_2.Id)

    # verify subscription schedule is correct
    stripe_id = sf_order[prefixed_stripe_field(GENERIC_STRIPE_ID)]
    subscription_schedule = Stripe::SubscriptionSchedule.retrieve({id: stripe_id, expand: %w{phases.items.price}}, @user.stripe_credentials)
    assert_equal(3, subscription_schedule.phases.count)

    first_phase = T.must(subscription_schedule.phases.first)
    assert_equal(1, first_phase.items.count)
    assert_equal(2, T.must(first_phase.items.first).quantity)

    second_phase = T.must(subscription_schedule.phases.second)
    assert_equal(2, second_phase.items.count)
    assert_equal(2, T.must(second_phase.items.first).quantity)
    # upgrade adds new product with this quantity
    assert_equal(3, T.must(second_phase.items.second).quantity)

    last_phase = T.must(subscription_schedule.phases.last)
    assert_equal(2, last_phase.items.count)
    assert_equal(2, T.must(last_phase.items.first).quantity)
    assert_equal(2, T.must(last_phase.items.second).quantity)
  end
end
