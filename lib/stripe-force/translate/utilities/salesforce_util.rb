# typed: true
# frozen_string_literal: true

# SalesforceUtil to avoid namespace madness with Stripe::* objects
module StripeForce::Utilities
  module SalesforceUtil
    extend T::Sig
    include Kernel

    include Integrations::Log
    include StripeForce::Constants

    # SF dates have no TZ data and come in as a simple 'YYYY-MM-DD'
    # Stripe APIs speak UTC, so we convert to UTC + unix timestamp
    sig { params(date_string: String).returns(Integer) }
    def self.salesforce_date_to_unix_timestamp(date_string)
      # TODO if beginning of day is in the past, maybe offer a 'now' option on the subscription?
      DateTime.parse(date_string).beginning_of_day.utc.to_i
    end

    sig { params(sf_id: String).returns(String) }
    def salesforce_type_from_id(sf_id)
      case sf_id
      when /^01s/
        SF_PRICEBOOK
      when /^01t/
        SF_PRODUCT
      when /^01u/
        SF_PRICEBOOK_ENTRY
      when /^001/
        SF_ACCOUNT
      when /^003/
        SF_CONTACT
      when /^800/
        SF_CONTRACT
      when /^801/
        SF_ORDER
      when /^802/
        SF_ORDER_ITEM
      when /^0Mh/
        SF_CONSUMPTION_SCHEDULE
      when /^0Mo/
        SF_CONSUMPTION_RATE
      else
        object_prefix = sf_id[0..2]
        object_description = @user
          .sf_client
          .api_get('sobjects')
          .body["sobjects"]
          .detect {|o| o["keyPrefix"] == object_prefix }

        # => {"activateable"=>false,
        #   "associateEntityType"=>nil,
        #   "associateParentEntity"=>nil,
        #   "createable"=>true,
        #   "custom"=>true,
        #   "customSetting"=>false,
        #   "deepCloneable"=>false,
        #   "deletable"=>true,
        #   "deprecatedAndHidden"=>false,
        #   "feedEnabled"=>false,
        #   "hasSubtypes"=>false,
        #   "isInterface"=>false,
        #   "isSubtype"=>false,
        #   "keyPrefix"=>"a0z",
        #   "label"=>"Quote",
        #   "labelPlural"=>"Quotes",
        #   "layoutable"=>true,
        #   "mergeable"=>false,
        #   "mruEnabled"=>true,
        #   "name"=>"SBQQ__Quote__c",
        #   "queryable"=>true,
        #   "replicateable"=>true,
        #   "retrieveable"=>true,
        #   "searchable"=>true,
        #   "triggerable"=>true,
        #   "undeletable"=>true,
        #   "updateable"=>true,
        #   "urls"=>
        #    {"compactLayouts"=>"/services/data/v52.0/sobjects/SBQQ__Quote__c/describe/compactLayouts",
        #     "rowTemplate"=>"/services/data/v52.0/sobjects/SBQQ__Quote__c/{ID}",
        #     "approvalLayouts"=>"/services/data/v52.0/sobjects/SBQQ__Quote__c/describe/approvalLayouts",
        #     "describe"=>"/services/data/v52.0/sobjects/SBQQ__Quote__c/describe",
        #     "quickActions"=>"/services/data/v52.0/sobjects/SBQQ__Quote__c/quickActions",
        #     "layouts"=>"/services/data/v52.0/sobjects/SBQQ__Quote__c/describe/layouts",
        #     "sobject"=>"/services/data/v52.0/sobjects/SBQQ__Quote__c"}}

        # https://help.salesforce.com/s/articleView?id=000325244&type=1
        if !object_description
          raise "unknown object type #{sf_id}"
        end

        # TODO https://jira.corp.stripe.com/browse/PLATINT-1536
        object_description["name"]
      end
    end

    sig { params(origin_salesforce_object: Restforce::SObject, salesforce_object: Restforce::SObject).returns(String) }
    def generate_compound_external_id(origin_salesforce_object, salesforce_object)
      "#{@origin_salesforce_object.Id}-#{salesforce_object.Id}"
    end

    sig { params(field_name: String).returns(String) }
    def prefixed_stripe_field(field_name)
      custom_field_prefix = case (salesforce_namespace = @user.connector_settings[CONNECTOR_SETTING_SALESFORCE_NAMESPACE])
      when nil
        Integrations::ErrorContext.report_edge_case("expected namespace to be defined, using fallback")
        ""
      when "c"
        ""
      when *SalesforceNamespaceOptions.values.map(&:serialize)
        # `stripeConnector_Stripe_ID__c` is the expected field name
        salesforce_namespace + "__"
      else
        raise "invalid namespace provided #{custom_field_prefix}"
      end

      custom_field_prefix + field_name
    end

    sig { params(options: {}).returns(T.untyped) }
    def backoff(options={})
      count = 0

      options[:attempts] ||= if ENV['SALESFORCE_BACKOFF_ATTEMPTS'].nil?
        MAX_SF_RETRY_ATTEMPTS
      else
        ENV['SALESFORCE_BACKOFF_ATTEMPTS'].to_i
      end

      begin
        count += 1

        # runs the block (if given) and returns if no errors raised
        yield if block_given?
      rescue Restforce::ErrorCode::UnableToLockRow,
             Restforce::ServerError,
             Restforce::NotFoundError,
             Faraday::ConnectionFailed,
             Faraday::TimeoutError,
             Restforce::ResponseError,
             Restforce::UnauthorizedError => e

        # log & raise error if all retries fail
        if count >= options[:attempts]
          log.warn 'finished retrying SF operation, raising error',
            attempt: count,
            error_class: e.class.to_s,
            error_message: e.message
          raise e
        end

        sleep(count * count)
        retry
      end
    end
  end
end
