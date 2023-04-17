# frozen_string_literal: true
# typed: true

require_relative '../test_helper'

class Critic::ConfigurationsControllerTest < ApplicationIntegrationTest
  describe "#translate_all" do
    before do
      @user = make_user(save: true)
    end

    it 'queues job for translation' do
      post api_translate_all_path, as: :json, params: {object_type: SF_ORDER}, headers: authentication_headers
      assert_response :success
    end
  end

  describe '#translate' do
    before do
      @user = make_user(save: true)
    end

    it 'validates the input' do
      post api_translate_path, as: :json
      assert_response :not_found

      post api_translate_path, headers: authentication_headers
      assert_response :not_acceptable

      post api_translate_path, as: :json, headers: authentication_headers
      assert_response :bad_request

      post api_translate_path, as: :json, params: {object_type: 'invalid', object_ids: ["123"]}, headers: authentication_headers
      assert_response :bad_request

      post api_translate_path, as: :json, params: {object_type: SF_ORDER, object_ids: 'not an array'}, headers: authentication_headers
      assert_response :bad_request
    end

    it 'queues jobs for translation' do
      number_of_orders = 5

      order_ids = number_of_orders.times.map do
        create_salesforce_id
      end

      SalesforceTranslateRecordJob.expects(:work).times(number_of_orders)

      post api_translate_path, as: :json, params: {object_type: 'Order', object_ids: order_ids}, headers: authentication_headers
      assert_response :success
    end

    it 'accepts account reference' do
      SalesforceTranslateRecordJob.expects(:work)

      post api_translate_path, as: :json, params: {object_type: SF_ACCOUNT, object_ids: [create_salesforce_id]}, headers: authentication_headers
      assert_response :success
    end

    it 'accepts product reference' do
      SalesforceTranslateRecordJob.expects(:work)

      post api_translate_path, as: :json, params: {object_type: SF_PRODUCT, object_ids: [create_salesforce_id]}, headers: authentication_headers
      assert_response :success
    end
  end

  describe '#post_install' do
    it 'rejects a invalid request' do
      post api_post_install_path, as: :json, headers: {SALESFORCE_KEY_HEADER => '123'}
      assert_response :not_found

      post api_post_install_path, as: :json
      assert_response :not_found

      post api_post_install_path, params: 'I am not json', headers: {SALESFORCE_KEY_HEADER => ENV.fetch('SF_MANAGED_PACKAGE_API_KEY'), SALESFORCE_ACCOUNT_ID_HEADER => sf_instance_account_id}
      assert_response :not_acceptable
    end

    it 'rejects a request with no organization api key' do
      post api_post_install_path, params: {}, as: :json, headers: {SALESFORCE_KEY_HEADER => ENV.fetch('SF_MANAGED_PACKAGE_API_KEY'), SALESFORCE_ACCOUNT_ID_HEADER => sf_instance_account_id}
      assert_response :bad_request
    end

    it 'creates a new user with a valid organization API key' do
      assert_equal(0, StripeForce::User.count)

      api_key = SecureRandom.alphanumeric(16)
      post api_post_install_path, params: {key: api_key}, as: :json, headers: {
        # not using `authentication_headers` since the user is not created
        SALESFORCE_KEY_HEADER => ENV.fetch('SF_MANAGED_PACKAGE_API_KEY'),
        SALESFORCE_ACCOUNT_ID_HEADER => sf_instance_account_id,
        SALESFORCE_INSTANCE_TYPE_HEADER => SFInstanceTypes::SANDBOX.serialize,
        SALESFORCE_PACKAGE_NAMESPACE_HEADER => "",
      }

      assert_equal(1, StripeForce::User.count)
      user = T.must(StripeForce::User.first)

      assert_equal(sf_instance_account_id, user.salesforce_account_id)
      assert_equal(api_key, user.salesforce_organization_key)
      assert_equal(SalesforceNamespaceOptions::PRODUCTION.serialize, user.connector_settings[CONNECTOR_SETTING_SALESFORCE_NAMESPACE])
      assert_equal(SFInstanceTypes::SANDBOX.serialize, user.connector_settings[CONNECTOR_SETTING_SALESFORCE_INSTANCE_TYPE])
    end

    it 'persists the salesforce namespace when in QA' do
      assert_equal(0, StripeForce::User.count)

      api_key = SecureRandom.alphanumeric(16)
      post api_post_install_path, params: {key: api_key}, as: :json, headers: {
        # not using `authentication_headers` since the user is not created
        SALESFORCE_KEY_HEADER => ENV.fetch('SF_MANAGED_PACKAGE_API_KEY'),
        SALESFORCE_ACCOUNT_ID_HEADER => sf_instance_account_id,
        SALESFORCE_PACKAGE_NAMESPACE_HEADER => SalesforceNamespaceOptions::QA.serialize,
        SALESFORCE_INSTANCE_TYPE_HEADER => SFInstanceTypes::PRODUCTION.serialize,
      }

      assert_equal(1, StripeForce::User.count)
      user = T.must(StripeForce::User.first)
      assert_equal(SalesforceNamespaceOptions::QA.serialize, user.connector_settings['salesforce_namespace'])
      assert_equal(SFInstanceTypes::PRODUCTION.serialize, user.connector_settings[CONNECTOR_SETTING_SALESFORCE_INSTANCE_TYPE])
    end
  end

  describe 'configuration' do
    before do
      @user = make_user
      @user.field_defaults = {
        "customer" => {
          "metadata.from_salesforce" => true,
        },
      }

      @user.field_mappings = {
        "customer" => {
          "FromSalesforce" => "metadata.from_salesforce",
        },
      }
      @user.save
    end

    describe 'errors' do
      it 'throws a 404 if no user id is passed' do
        get api_configuration_path
        assert_response :not_found
      end

      it 'throws a 404 if invalid user is passed' do
        get api_configuration_path, headers: authentication_headers.merge({SALESFORCE_ACCOUNT_ID_HEADER => create_salesforce_id})
        assert_response :not_found
      end

      it 'throws a not accepted error if JSON is not passed' do
        put api_configuration_path, params: "i am not json", headers: authentication_headers
        assert_response :not_acceptable
      end

      # DB enforces that SF org IDs must be unique

      it 'throws an error if the api key does not match' do
        get api_configuration_path, params: {}, headers: authentication_headers.merge(
          SALESFORCE_KEY_HEADER => SecureRandom.alphanumeric(16)
        )

        assert_response :not_found
      end

      it 'throws an error if no api key is specified' do
        get api_configuration_path, params: {}, headers: authentication_headers.merge(
          SALESFORCE_KEY_HEADER => ""
        )

        assert_response :not_found
      end
    end

    describe '#show' do
      it 'returns user status JSON' do
        assert_equal(1, StripeForce::User.count)

        get api_configuration_path, headers: authentication_headers

        assert_response :success

        result = parsed_json

        refute_nil(result['default_mappings'])
        refute_nil(result['required_mappings'])
        refute_nil(result['feature_flags'])

        assert_equal(@user.salesforce_account_id, result["salesforce_account_id"])
        assert_equal(@user.field_mappings, result["field_mappings"])
        assert_equal(@user.field_defaults, result["field_defaults"])

        assert_equal(95, result['settings']['api_percentage_limit'])
        assert_equal(10_000, result['settings']['sync_record_retention'])
        assert_equal('USD', result['settings']['default_currency'])
        assert_nil(result['settings']['sync_start_date'])
        refute(result['settings']['polling_enabled'])
        assert_equal(40, result['configuration_hash'].size)
        assert(result['enabled'])

        assert_nil(result['connection_status']['last_synced'])

        refute_nil(result['settings']['filters'])
        assert_equal("Status = 'Activated'", result['settings']['filters'][SF_ORDER])
        assert_nil(result['settings']['filters'][SF_ACCOUNT])
        assert_nil(result['settings']['filters'][SF_PRODUCT])
      end

      it 'updates the configuration_hash when mappings change' do
        get api_configuration_path, headers: authentication_headers
        assert_response :success
        result = parsed_json

        initial_hash = result['configuration_hash']

        get api_configuration_path, headers: authentication_headers
        assert_response :success
        result = parsed_json

        # hash should remain the same when something doesn't change
        assert_equal(initial_hash, result['configuration_hash'])

        @user.field_mappings['price'] = {'special' => 'mapping'}
        @user.save

        get api_configuration_path, headers: authentication_headers
        assert_response :success
        result = parsed_json

        # if mappings change, hash should be different
        refute_equal(initial_hash, result['configuration_hash'])
        assert_equal(40, result['configuration_hash'].size)
      end

      it 'hidden mapper fields is updated when features are enabled' do
        get api_configuration_path, headers: authentication_headers
        assert_response :success
        result = parsed_json

        # initially the hidden mapper fields should contain values
        # if no feature flag is enabled for the user
        assert(2, result['hidden_mapper_fields'].count)
        assert_equal(["coupon", "subscription_schedule.prebilling.iterations", "subscription_schedule.default_settings.invoice_settings.rendering.template", "subscription_schedule.default_settings.invoice_settings.rendering.template_version"], result['hidden_mapper_fields'])

        # enable features
        @user.enable_feature(FeatureFlags::COUPONS)
        @user.enable_feature(FeatureFlags::PREBILLING)
        @user.save

        get api_configuration_path, headers: authentication_headers
        assert_response :success
        result = parsed_json

        # if mappings change, hash should be different
        assert_equal([], result['hidden_mapper_fields'])
      end
    end

    describe '#configuration' do
      it 'updates settings' do
        assert(@user.enabled)

        future_time = Time.now.to_i + 3600

        put api_configuration_path, params: {
          enabled: false,
          settings: {
            api_percentage_limit: 90,
            sync_start_date: future_time,
            sync_record_retention: 1_000,
            default_currency: 'EUR',
            polling_enabled: true,
          },
        }, as: :json, headers: authentication_headers

        assert_response :success

        result = parsed_json

        @user = T.must(StripeForce::User[@user.id])

        assert_equal(90, result['settings']['api_percentage_limit'])
        assert_equal(1_000, result['settings']['sync_record_retention'])
        assert_equal('EUR', result['settings']['default_currency'])
        assert(result['settings']['polling_enabled'])
        assert_equal(result['settings']['sync_start_date'], future_time)
        assert(result['enabled'] == @user.enabled && @user.enabled == false)
      end

      it 'does not remove settings which are not present in the incoming hash' do
        @user.connector_settings['salesforce_namespace'] = SalesforceNamespaceOptions::QA.serialize
        @user.save

        put api_configuration_path, params: {
          settings: {
            default_currency: 'EUR',
          },
        }, as: :json, headers: authentication_headers

        assert_response :success

        result = parsed_json

        @user = T.must(StripeForce::User[@user.id])

        assert_equal('EUR', @user.connector_settings['default_currency'])
        assert_equal(SalesforceNamespaceOptions::QA.serialize, @user.connector_settings['salesforce_namespace'])
        assert(result['enabled'])
      end

      it 'updates mappings and defaults without settings' do
        updated_field_mapping = {
          "subscription_schedule" => {
            "Email" => "email",
          },
          "customer" => {},
        }

        updated_field_defaults = {
          "customer" => {
            "phone" => "1231231234",
          },
        }

        put api_configuration_path, params: {
          field_mappings: updated_field_mapping,
          field_defaults: updated_field_defaults,
        }, as: :json, headers: authentication_headers

        assert_response :success

        result = parsed_json

        @user = T.must(StripeForce::User[@user.id])

        assert_equal(@user.field_mappings, updated_field_mapping)
        assert_equal(@user.field_defaults, updated_field_defaults)
        assert(result['enabled'])

        assert_equal(@user.field_mappings, result["field_mappings"])
        assert_equal(@user.field_defaults, result["field_defaults"])
      end

      it 'preserves keys which are not supported in the mapper' do
        @user.field_mappings['special_key'] = {
          'Description' => 'metadata.special_key',
        }

        @user.field_defaults['special_key'] = {
          'metadata.special_key' => 'special_value',
        }

        # this should be replaced when a payload is passed from the mapper
        @user.field_mappings['subscription'] = {
          'Description' => 'metadata.normal_key',
        }

        @user.save

        put api_configuration_path, params: {
          "field_mappings" => {
            "subscription" => {
              'Description' => 'metadata.passed_key',
            },
            "customer" => {},
          },
          "field_defaults" => {
            "customer": {
              "some": "key",
            },
          },
        }, as: :json, headers: authentication_headers

        assert_response :success

        @user = T.must(StripeForce::User[@user.id])

        assert_equal({'Description' => 'metadata.passed_key'}, @user.field_mappings['subscription'])
        assert_equal({'Description' => 'metadata.special_key'}, @user.field_mappings['special_key'])

        assert_equal({'some' => 'key'}, @user.field_defaults['customer'])
        assert_equal({'metadata.special_key' => 'special_value'}, @user.field_defaults['special_key'])
      end

      it 'succeeds if the user content has not changed' do
        get api_configuration_path, headers: authentication_headers
        assert_response :success
        result = parsed_json

        configuration_hash = result['configuration_hash']
        assert(configuration_hash)

        put api_configuration_path, params: {
          "configuration_hash" => configuration_hash,
          "field_mappings" => {},
          "field_defaults" => {},
        }, as: :json, headers: authentication_headers

        assert_response :success
      end

      it 'fails if the user content has changed since the managed package ui was loaded' do
        get api_configuration_path, headers: authentication_headers
        assert_response :success
        result = parsed_json

        configuration_hash = result['configuration_hash']
        assert(configuration_hash)

        @user.field_defaults["customer"] = {"async" => "change"}
        @user.save

        put api_configuration_path, params: {
          "configuration_hash" => configuration_hash,
          "field_mappings" => {},
          "field_defaults" => {},
        }, as: :json, headers: authentication_headers

        assert_response :conflict
        failure_result = parsed_json
        assert_equal("Another user has updated the account. Refresh your account and try again.", failure_result["error"])
      end
    end
  end
end
