# typed: true
# frozen_string_literal: true

require_relative '../../test_helper'

class Critic::RevenueContractValidationHelper < Critic::FunctionalTest
  def revenue_contract_validate_basics(
    sf_order,
    subscription_schedule,
    revenue_contract,
    sf_account_id,
    signed_date
  )
    customer = Stripe::Customer.retrieve(T.cast(subscription_schedule.customer, String), @user.stripe_credentials)

    # basic customer creation check
    refute_empty(customer.name)
    assert_nil(customer.email)
    assert_equal(customer.id, revenue_contract.customer)

    assert_match(sf_account_id, customer.metadata['salesforce_account_link'])
    assert_equal(customer.metadata['salesforce_account_id'], sf_account_id)

    # top level subscription fields
    assert_match(sf_order.Id, subscription_schedule.metadata['salesforce_order_link'])
    assert_equal(subscription_schedule.metadata['salesforce_order_id'], sf_order.Id)
    assert_equal(signed_date, subscription_schedule.metadata['contract_cf_signed_date'])

    # top level contract fields
    # These are only specific to creation right now, will need to update when we handle amendments
    assert_equal("signed", revenue_contract.status)
    assert_equal(DateTime.parse(signed_date).to_i, revenue_contract.status_transitions.signed_at)
    assert_equal(1, revenue_contract.version)
    assert_equal(subscription_schedule.metadata['salesforce_order_link'], revenue_contract.metadata['salesforce_order_link'])
    assert_equal(subscription_schedule.metadata['salesforce_order_id'], revenue_contract.metadata['salesforce_order_id'])
    assert_equal(subscription_schedule.metadata['contract_cf_signed_date'], revenue_contract.metadata['contract_cf_signed_date'])
    assert_equal(subscription_schedule.metadata.count, revenue_contract.metadata.count)
  end

  def revenue_contract_validate_item(
    phase_item,
    contract_item,
    sf_pricebook_entry,
    quantity,
    amount,
    tfc
  )
    assert_equal(sf_pricebook_entry[prefixed_stripe_field(GENERIC_STRIPE_ID)], phase_item.price)
    assert_equal(sf_pricebook_entry[prefixed_stripe_field(GENERIC_STRIPE_ID)], contract_item.price)

    assert_equal(quantity, phase_item.quantity)
    assert_equal(quantity, contract_item.quantity)

    assert_equal(amount, contract_item.amount_subtotal)
    if !tfc.nil?
      assert_equal(tfc.to_s, phase_item.metadata['contract_tfc_duration'])
      assert_equal(tfc.to_s, contract_item.metadata['contract_tfc_duration'])
      assert_equal(contract_item.period.start + (tfc + 1).days, contract_item.termination_for_convenience.expires_at)
    else
      assert_nil(contract_item.termination_for_convenience)
    end

    assert_equal(phase_item.metadata.count, contract_item.metadata.count)
    if !phase_item.metadata['item_contract_value'].nil?
      assert_equal(amount.to_s, phase_item.metadata['item_contract_value'])
      assert_equal(amount.to_s, contract_item.metadata['item_contract_value'])
    end
  end
end
