# typed: true
# frozen_string_literal: true

require_relative './salesforce_factory'
require_relative './salesforce_debugging'

module CommonHelpers
  include Kernel
  extend T::Sig

  include StripeForce::Constants
  include Critic::SalesforceFactory

  # NOTE this is a little dangerous: we are only doing this for `prefixed_stripe_field` right now
  include StripeForce::Utilities::SalesforceUtil

  include SalesforceDebugging

  def sf_account_id
    ENV.fetch('SF_INSTANCE_ID')
  end

  def sf_get(sf_id)
    sf_type = salesforce_type_from_id(sf_id)
    @user.sf_client.find(sf_type, sf_id)
  end

  sig { params(sandbox: T::Boolean, save: T::Boolean, random_user_id: T::Boolean).returns(StripeForce::User) }
  def make_user(sandbox: false, save: false, random_user_id: false)
    user = StripeForce::User.new(
      livemode: false,

      salesforce_account_id: sf_account_id,
      salesforce_token: ENV.fetch('SF_ACCESS_TOKEN'),
      salesforce_refresh_token: ENV['SF_REFRESH_TOKEN'],
      salesforce_instance_url: "https://#{ENV.fetch('SF_INSTANCE_DOMAIN')}.my.salesforce.com",

      stripe_account_id: if random_user_id
        create_id("acct_")
      else
        ENV.fetch('STRIPE_ACCOUNT_ID')
      end
    )

    # mbianco+cpqpackage@stripe.com
    if user.salesforce_account_id == "00D8c000006J9X9EAK"
      user.connector_settings[CONNECTOR_SETTING_SALESFORCE_NAMESPACE] = SalesforceNamespaceOptions::QA.serialize
    else
      user.connector_settings[CONNECTOR_SETTING_SALESFORCE_NAMESPACE] = SalesforceNamespaceOptions::NONE.serialize
    end

    user.connector_settings[CONNECTOR_SETTING_SALESFORCE_INSTANCE_TYPE] = SFInstanceTypes::SANDBOX.serialize
    user.save if save

    user
  end

  def create_id(prefix)
    # NOTE: The number after the underscore has significance for Stripe's internal routing.
    #   While we don't expect these IDs to be used for real API calls, we want to ensure
    #   they don't lead to unexpected behavior if they are.
    random_id = "_1" + SecureRandom.alphanumeric(29)

    if ENV['CIRCLE_NODE_INDEX']
      random_id = "#{random_id}#{ENV['CIRCLE_NODE_INDEX']}"
    end

    prefix.to_s + random_id
  end

  def sf
    @user.sf_client
  end

  def inline_job_processing!
    Resque.inline = true
  end

  def normal_job_processing!
    Resque.inline = false
  end

  def common_setup
    # https://github.com/resque/resque-scheduler/pull/602
    redis.redis.flushdb

    inline_job_processing!

    DatabaseCleaner.start

    # KMSEncryptionTestHelpers.mock_encryption_fields(StripeSuite::User)

    Integrations::Metrics::Writer.instance.timer.shutdown
    Integrations::Metrics::Writer.instance.queue.clear

    # output current test, useful for debugging which fail because of CI timeout limits
    T.bind(self, ActiveSupport::TestCase)
    puts self.location
  end

  def common_teardown
    DatabaseCleaner.clean
  end

  def redis
    Resque.redis
  end
end
