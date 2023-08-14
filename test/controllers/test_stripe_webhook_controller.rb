# frozen_string_literal: true
# typed: true
require_relative '../test_helper'

class StripeWebhookTest < ApplicationIntegrationTest
  before { use_https_protocol }

  def send_webhook(payload, signature: nil)
    signature ||= begin
      t = Time.now.to_i
      s = Stripe::Webhook::Signature.compute_signature(
        Time.now,
        payload.to_json.to_s,
        ENV.fetch('STRIPE_WEBHOOK_SECRET')
      )
      "t=#{t},v1=#{s}"
    end

    # https://github.com/rails/rails/blob/070d4afacd3e9721b7e3a4634e4d026b5fa2c32c/actionpack/test/controller/rescue_test.rb#L298
    post stripe_webhooks_url,
      params: payload,
      # without `as` these tests will fail due to `ActionDispatch::Http::Parameters::ParseError`
      # https://github.com/rails/rails/issues/38285#issuecomment-659848119
      as: :json,
      headers: {'Stripe-Signature' => signature}
  end

  it 'handles invalid JSON payloads' do
    send_webhook('boom-boom-pow')

    assert_equal(400, response.status, response.body)
    assert_equal("Invalid payload", response.body)
  end

  it "handles invalid Stripe signatures" do
    send_webhook({'foo' => 'bar'}, signature: "not-a-real-signature")

    assert_equal(400, response.status, response.body)
    assert_match(/Invalid request/, response.body)
  end

  it 'handles unknown users' do
    e = create_event('charge.succeeded')
    send_webhook(e)

    assert_equal(404, response.status, response.body)
    assert_match(/not found/, response.body)
  end

  describe 'handling a valid webhook' do
    before do
      @user = make_user(livemode: false)
      StripeForce::User.stubs(:find).returns(@user)
    end

    it 'handles a valid webhook' do
      e = create_event('invoiceitem.created')

      StripeForce::ProrationAutoBill.expects(:create_invoice_from_invoice_item_event).once

      send_webhook(e)
      assert_equal(200, response.status, response.body)
      assert_match(/Successfully processed event/, response.body)
    end

    it 'is not rate limited' do
      e = create_event('charge.succeeded')

      100.times do
        send_webhook(e)
        assert_equal(200, response.status, response.body)
      end
    end


    it 'skips all webhooks if ignore_all_webhooks is enabled' do
      @user.enable_feature FeatureFlags::IGNORE_WEBHOOKS

      StripeForce::ProrationAutoBill.expects(:create_invoice_from_invoice_item_event).never

      e = create_event('charge.succeeded')
      send_webhook(e)
      assert_equal(200, response.status, response.body)
      assert_match("user exists, but webhook ignored", response.body)

      e = create_event('charge.failed')
      send_webhook(e)
      assert_equal(200, response.status, response.body)

      e = create_event('charge.pending')
      assert_equal(200, response.status, response.body)
      send_webhook(e)
    end

    it 'rejects webhooks if reject_all_webhooks is enabled' do
      @user.enable_feature FeatureFlags::REJECT_WEBHOOKS

      e = create_event('charge.succeeded')

      StripeForce::ProrationAutoBill.expects(:create_invoice_from_invoice_item_event).never

      send_webhook(e)
      assert_equal(503, response.status, response.body)
      assert_match("user exists, but webhook rejected", response.body)
    end

    it 'creates evergreen order when webhook is fired' do
      @user.enable_feature FeatureFlags::BIDIRECTIONAL_SYNC_DEMO
      # Most recent order before webhook fired
      previous_order = sf_get_recent("Order")

      e = create_event('customer.subscription.created')
      send_webhook(e)

      # Most recent order after webhook fired
      sf_evergreen_order = sf_get_recent(SF_ORDER)

      # The most recent order before and after the webhook is fired should be different, indicating that we've created a new order
      # by firing the webhook
      assert_not_equal(previous_order.Id, sf_evergreen_order.Id)

      order_items = sf_get_related(sf_evergreen_order, SF_ORDER_ITEM)

      order_items.each do |order_item|
        assert_equal(1, order_item[CPQ_QUOTE_SUBSCRIPTION_TERM])
        assert_equal(CPQProductSubscriptionTypeOptions::EVERGREEN.serialize, order_item[CPQ_PRODUCT_SUBSCRIPTION_TYPE])
        assert_equal('Fixed Price', order_item[CPQ_QUOTE_SUBSCRIPTION_PRICING])
      end

      # Ensure that a valid stripe ID is being set
      stripe_id = @user.sf_client.query("Select #{GENERIC_STRIPE_ID} from #{SF_ORDER} where Id = '#{sf_evergreen_order.Id}'")
      assert_not_empty(stripe_id)
    end
  end
end
