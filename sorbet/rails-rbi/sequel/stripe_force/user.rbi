# This is an autogenerated file for dynamic methods in StripeForce::User
# Please rerun bundle exec scripts/sequel-types.rb to regenerate
# typed: strong
module StripeForce::User::GeneratedAttributeMethods
  sig { returns(DateTime) }
  def created_at; end

  sig { params(value: T.any(DateTime, Date, Time)).void }
  def created_at=(value); end

  sig { returns(T.nilable(String)) }
  def email; end

  sig { params(value: T.nilable(T.any(String, Symbol))).void }
  def email=(value); end

  sig { returns(T::Boolean) }
  def enabled; end

  sig { params(value: T::Boolean).void }
  def enabled=(value); end

  sig { returns(T.any(T::Array[T.untyped], T::Hash[String, T.untyped])) }
  def feature_flags; end

  sig { params(value: T.any(T::Array[T.untyped], T::Hash[String, T.untyped])).void }
  def feature_flags=(value); end

  sig { returns(T.any(T::Array[T.untyped], T::Hash[String, T.untyped])) }
  def field_defaults; end

  sig { params(value: T.any(T::Array[T.untyped], T::Hash[String, T.untyped])).void }
  def field_defaults=(value); end

  sig { returns(T.any(T::Array[T.untyped], T::Hash[String, T.untyped])) }
  def field_mappings; end

  sig { params(value: T.any(T::Array[T.untyped], T::Hash[String, T.untyped])).void }
  def field_mappings=(value); end

  sig { returns(Integer) }
  def id; end

  sig { params(value: T.any(Numeric)).void }
  def id=(value); end

  sig { returns(T::Boolean) }
  def livemode; end

  sig { params(value: T::Boolean).void }
  def livemode=(value); end

  sig { returns(T.nilable(String)) }
  def name; end

  sig { params(value: T.nilable(T.any(String, Symbol))).void }
  def name=(value); end

  sig { returns(String) }
  def salesforce_account_id; end

  sig { params(value: T.any(String, Symbol)).void }
  def salesforce_account_id=(value); end

  sig { returns(T.nilable(String)) }
  def salesforce_instance_url; end

  sig { params(value: T.nilable(T.any(String, Symbol))).void }
  def salesforce_instance_url=(value); end

  sig { returns(T.nilable(String)) }
  def salesforce_organization_key; end

  sig { params(value: T.nilable(T.any(String, Symbol))).void }
  def salesforce_organization_key=(value); end

  sig { returns(T.nilable(String)) }
  def salesforce_refresh_token; end

  sig { params(value: T.nilable(T.any(String, Symbol))).void }
  def salesforce_refresh_token=(value); end

  sig { returns(T.nilable(String)) }
  def salesforce_token; end

  sig { params(value: T.nilable(T.any(String, Symbol))).void }
  def salesforce_token=(value); end

  sig { returns(T.nilable(String)) }
  def stripe_account_id; end

  sig { params(value: T.nilable(T.any(String, Symbol))).void }
  def stripe_account_id=(value); end

  sig { returns(T.nilable(String)) }
  def stripe_public_token; end

  sig { params(value: T.nilable(T.any(String, Symbol))).void }
  def stripe_public_token=(value); end

  sig { returns(T.nilable(String)) }
  def stripe_refresh_token; end

  sig { params(value: T.nilable(T.any(String, Symbol))).void }
  def stripe_refresh_token=(value); end

  sig { returns(DateTime) }
  def updated_at; end

  sig { params(value: T.any(DateTime, Date, Time)).void }
  def updated_at=(value); end
end

class StripeForce::User < Sequel::Model
  include StripeForce::User::GeneratedAttributeMethods

  sig { params(value: T::Hash[T.untyped, T.untyped]).returns(T.nilable(StripeForce::User)) }
  def self.find(value); end

  sig { params(value: Integer).returns(T.nilable(StripeForce::User)) }
  def self.[](value); end

  sig { returns(T.nilable(StripeForce::User)) }
  def self.first; end

  sig { returns(T.nilable(StripeForce::User)) }
  def self.last; end
end
