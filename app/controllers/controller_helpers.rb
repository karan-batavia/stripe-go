# frozen_string_literal: true
# typed: strict

module ControllerHelpers
  extend T::Sig
  include Kernel

  include StripeForce::Constants
  include Integrations::ErrorContext

  # https://github.com/stripe/stripe-salesforce/pull/171
  sig { params(raw_namespace: T.nilable(String)).returns(String) }
  protected def subdomain_namespace_from_param(raw_namespace)
    case raw_namespace
    when nil, ""
      Integrations::ErrorContext.report_edge_case("namespace should not be empty")
      SalesforceNamespaceOptions::PRODUCTION.serialize
    when *SalesforceNamespaceOptions.values.map(&:serialize)
      raw_namespace
    else
      raise "unexpected namespace: #{raw_namespace}"
    end
  end

  sig { params(user: StripeForce::User, raw_namespace: T.nilable(String)).returns(String) }
  protected def build_postmessage_domain(user, raw_namespace)
    salesforce_namespace = subdomain_namespace_from_param(raw_namespace)
    iframe_domain = iframe_domain_from_user(user)
    "https://#{user.sf_subdomain}--#{salesforce_namespace}.#{iframe_domain}"
  end

  sig { params(user: StripeForce::User).returns(String) }
  protected def iframe_domain_from_user(user)
    if user.scratch_org?
      "vf.force.com"
    else
      "visualforce.com"
    end
  end
end
