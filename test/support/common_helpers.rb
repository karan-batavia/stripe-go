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

  def sf_instance_account_id
    ENV.fetch('SF_INSTANCE_ID')
  end

  def get_sync_records_by_primary_id(primary_id)
    sync_record_results = sf.query("SELECT Id FROM #{prefixed_stripe_field(SYNC_RECORD)} WHERE #{prefixed_stripe_field(SyncRecordFields::PRIMARY_RECORD_ID.serialize)} = '#{primary_id}'")


    sync_records = []
    sync_record_results.each do |sync_record|
      sync_record = sf.find(prefixed_stripe_field(SYNC_RECORD), sync_record.Id)
      sync_records.append(sync_record)
    end

    sync_records
  end

  # The get_sync_record_by_secondary_id does not make sense with the addition of Success Sync records, as that is the grouping ID.
  #  ie the translation of an Order would create multiple sync records, ie (Account, Product2, PricebookEntry as well as the Order itself).
  # This helper will fetch by the secondary id, ie the id of the actual object the sync record pertains to. Not the parent one that caused its creation.
  def get_sync_record_by_secondary_id(secondary_id)
    sync_record_results = sf.query("SELECT Id FROM #{prefixed_stripe_field(SYNC_RECORD)} WHERE #{prefixed_stripe_field(SyncRecordFields::SECONDARY_RECORD_ID.serialize)} = '#{secondary_id}'")

    assert_equal(1, sync_record_results.count)

    sync_record = sf.find(prefixed_stripe_field(SYNC_RECORD), sync_record_results.first.Id)
  end

  sig { params(user: T.nilable(StripeForce::User)).returns(StripeForce::Translate) }
  def make_translator(user: nil)
    user ||= make_user
    locker = Integrations::Locker.new(user)

    StripeForce::Translate.new(
      user,
      locker
    )
  end

  sig { params(sandbox: T::Boolean, save: T::Boolean, random_user_id: T::Boolean, livemode: T::Boolean).returns(StripeForce::User) }
  def make_user(sandbox: false, save: false, random_user_id: false, livemode: false)
    user = StripeForce::User.new(
      livemode: livemode,

      salesforce_account_id: sf_instance_account_id,
      salesforce_token: ENV.fetch('SF_ACCESS_TOKEN'),
      salesforce_refresh_token: ENV['SF_REFRESH_TOKEN'],
      salesforce_instance_url: "https://#{ENV.fetch('SF_INSTANCE_DOMAIN')}.my.salesforce.com",
      salesforce_organization_key: SecureRandom.alphanumeric(16),

      stripe_account_id: if random_user_id
        stripe_create_id("acct_")
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

    # clocks won't be enabled in prod, so we want to mimic this
    user.disable_feature(FeatureFlags::TEST_CLOCKS)

    user.connector_settings[CONNECTOR_SETTING_SALESFORCE_INSTANCE_TYPE] = SFInstanceTypes::SANDBOX.serialize
    user.save if save

    user
  end

  sig { params(type: String, obj: T.nilable(Stripe::StripeObject)).returns(Stripe::Event) }
  def create_event(type, obj=nil)
    obj ||= Stripe::Charge.construct_from(
      id: stripe_create_id(:ch)
    )

    Stripe::Event.construct_from({
      "id" => stripe_create_id(:evt),
      "created" => Time.now.getutc.to_i,
      "livemode" => false,
      "type" => type,
      "data" => {
        "object" => JSON.parse(obj.to_json),
      },
      "object" => "event",
      "pending_webhooks" => 0,
      "account" => stripe_create_id(:acct),
      "request" => stripe_create_id(:iar),
    })
  end

  def stripe_create_id(prefix)
    # NOTE: The number after the underscore has significance for Stripe's internal routing.
    #   While we don't expect these IDs to be used for real API calls, we want to ensure
    #   they don't lead to unexpected behavior if they are.
    random_id = "_1" + SecureRandom.alphanumeric(29)

    if ENV['CIRCLE_NODE_INDEX']
      random_id = "#{random_id}#{ENV['CIRCLE_NODE_INDEX']}"
    end

    prefix.to_s + random_id
  end

  # Helper to poll for an expected result
  sig do
    params(
      timeout: T.any(Numeric, ActiveSupport::Duration),   # Max time to attempt polling. In seconds if not defined as a Duration
      interval: T.any(Numeric, ActiveSupport::Duration),  # Time to wait before retrying. In seconds if not defined as a Duration
      block: Proc,                # Method that is attempted to start and after each interval. If a truthy value is returned, the
    )                             #     polling will stop and that value is returned.
    .void
  end
  def wait_until(timeout: 30.seconds, interval: 1.seconds, &block)
    condition_met = T.let(false, T::Boolean)

    Timeout.timeout(timeout) do
      condition_met = yield block
      until condition_met
        puts "Condition not met, waiting #{interval.seconds} seconds"
        sleep(interval.seconds)
        condition_met = yield block
      end
      condition_met
    end
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
    assert_equal(0, StripeForce::User.count)

    # https://github.com/resque/resque-scheduler/pull/602
    redis.redis.flushdb

    inline_job_processing!

    DatabaseCleaner.start

    KMSEncryptionTestHelpers.mock_encryption_fields(StripeForce::User)

    Integrations::Metrics::Writer.instance.timer.shutdown
    Integrations::Metrics::Writer.instance.queue.clear

    # output current test, useful for debugging which fail because of CI timeout limits
    T.bind(self, ActiveSupport::TestCase)
    puts "\n\n" + self.location
  end

  def common_teardown
    DatabaseCleaner.clean
  end

  def redis
    Resque.redis
  end
end
