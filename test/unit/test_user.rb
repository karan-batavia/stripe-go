# frozen_string_literal: true
# typed: true
require_relative '../test_helper'

module Critic::Unit
  class UserTest < Critic::UnitTest
    before do
      @user = make_user
    end

    describe 'credentials refresh' do
      it 'does not refresh credentials when they are unchanged' do
        @user.expects(:update).never
        @user.persist_refreshed_credentials
      end

      it 'refreshes credentials when they are expired' do
        bad_creds = SecureRandom.alphanumeric(32)

        @user.salesforce_token = bad_creds
        @user.save

        @user.sf_client.options[:oauth_token] = ENV.fetch('SF_ACCESS_TOKEN')
        @user.persist_refreshed_credentials

        @user = T.must(StripeForce::User[@user.id])
        assert_equal(ENV.fetch('SF_ACCESS_TOKEN'), @user.salesforce_token)
      end
    end

    describe 'host selection' do
      it 'uses a test host when not in production' do
        @user.connector_settings[CONNECTOR_SETTING_SALESFORCE_INSTANCE_TYPE] = SFInstanceTypes::SANDBOX.serialize

        assert_equal('test.salesforce.com', @user.sf_client.options[:host])
      end

      it 'uses a standard host when in production' do
        @user.connector_settings[CONNECTOR_SETTING_SALESFORCE_INSTANCE_TYPE] = SFInstanceTypes::PRODUCTION.serialize

        assert_equal('login.salesforce.com', @user.sf_client.options[:host])
      end
    end

    it 'validates credentials' do
      assert(@user.valid_credentials?)

      sleep StripeForce::Constants::CACHED_CREDENTIAL_STATUS_TTL

      @user.sf_client.stubs(:user_info).raises(Restforce::AuthenticationError)
      refute(@user.valid_credentials?)

      sleep StripeForce::Constants::CACHED_CREDENTIAL_STATUS_TTL

      @user.sf_client.unstub(:user_info)
      assert(@user.valid_credentials?)

      sleep StripeForce::Constants::CACHED_CREDENTIAL_STATUS_TTL

      Stripe::Account.stubs(:retrieve).raises(Stripe::AuthenticationError)
      refute(@user.valid_credentials?)
    end

    it 'validates and caches credentials' do
      assert_nil(@user.get_cached_connection_status(StripeForce::Constants::Platforms::STRIPE))
      assert_nil(@user.get_cached_connection_status(StripeForce::Constants::Platforms::SALESFORCE))

      assert(@user.valid_credentials?)

      assert(@user.get_cached_connection_status(StripeForce::Constants::Platforms::STRIPE))
      assert(@user.get_cached_connection_status(StripeForce::Constants::Platforms::SALESFORCE))

      # 5 seconds for test runs
      sleep StripeForce::Constants::CACHED_CREDENTIAL_STATUS_TTL

      # Make sure the cache was evicted so they will be refreshed on next check
      assert_nil(@user.get_cached_connection_status(StripeForce::Constants::Platforms::STRIPE))
      assert_nil(@user.get_cached_connection_status(StripeForce::Constants::Platforms::SALESFORCE))
    end

    describe '#stripe_credentials' do
      # minitest doesn't have around hooks :(
      before(:each) do
        # doing this so that it will not be equivalent to STRIPE_API_KEY, which
        # is needed to keep these tests meaningful
        # there's another test where STRIPE_TEST_API_KEY needs to be a real key
        StripeForce::User.send(:remove_const, :SF_STRIPE_TESTMODE_API_KEY)
        StripeForce::User.const_set(:SF_STRIPE_TESTMODE_API_KEY, 'thisisafakekeyfortests')
      end

      after(:each) do
        StripeForce::User.send(:remove_const, :SF_STRIPE_TESTMODE_API_KEY)
        StripeForce::User.const_set(:SF_STRIPE_TESTMODE_API_KEY, ENV.fetch('STRIPE_TEST_API_KEY'))
      end

      def make_user_for_client_credentials_tests(overrides={})
        user = make_user(overrides)
        user
      end

      it "returns platform keys if in the flag" do
        user = make_user(livemode: true)

        credentials = user.stripe_credentials

        assert(credentials.key?(:api_key))
        assert(credentials.key?(:stripe_account))
        assert_equal(
          user.stripe_account_id,
          credentials.fetch(:stripe_account),
        )
      end

      it "when enabled returns platform livemode keys for livemode" do
        user = make_user(livemode: true)

        credentials = user.stripe_credentials

        refute_equal(
          StripeForce::User::SF_STRIPE_LIVEMODE_API_KEY,
          StripeForce::User::SF_STRIPE_TESTMODE_API_KEY
        )
        assert_equal(
          StripeForce::User::SF_STRIPE_LIVEMODE_API_KEY,
          credentials.fetch(:api_key),
        )
      end

      it "returns platform testmode keys for testmode" do
        user = make_user(livemode: false)

        credentials = user.stripe_credentials

        refute_equal(
          StripeForce::User::SF_STRIPE_LIVEMODE_API_KEY,
          StripeForce::User::SF_STRIPE_TESTMODE_API_KEY
        )
        assert_equal(
          StripeForce::User::SF_STRIPE_TESTMODE_API_KEY,
          credentials.fetch(:api_key),
        )
      end

      it 'can force livemode keys' do
        user = make_user(livemode: false)

        credentials = user.stripe_credentials(forced_livemode: true)

        refute_equal(
          StripeForce::User::SF_STRIPE_LIVEMODE_API_KEY,
          StripeForce::User::SF_STRIPE_TESTMODE_API_KEY
        )
        assert_equal(
          StripeForce::User::SF_STRIPE_LIVEMODE_API_KEY,
          credentials.fetch(:api_key),
        )
      end

      it 'can force testmode keys' do
        user = make_user(livemode: true)

        credentials = user.stripe_credentials(forced_livemode: false)

        refute_equal(
          StripeForce::User::SF_STRIPE_LIVEMODE_API_KEY,
          StripeForce::User::SF_STRIPE_TESTMODE_API_KEY
        )
        assert_equal(
          StripeForce::User::SF_STRIPE_TESTMODE_API_KEY,
          credentials.fetch(:api_key),
        )
      end

      it 'does not specify an api version by default' do
        user = make_user

        credentials = user.stripe_credentials

        assert_nil(credentials[:stripe_version])
      end
    end
  end
end
