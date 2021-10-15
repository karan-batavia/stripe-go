# typed: strong
# This is an autogenerated file for Rails routes.
# Please run bundle exec rake rails_rbi:routes to regenerate.
class ActionController::Base
  include GeneratedUrlHelpers
end

class ActionController::API
  include GeneratedUrlHelpers
end

module ActionView::Helpers
  include GeneratedUrlHelpers
end

class ActionMailer::Base
  include GeneratedUrlHelpers
end

module GeneratedUrlHelpers
  # Sigs for route /
  sig { params(args: T.untyped, kwargs: T.untyped).returns(String) }
  def root_path(*args, **kwargs); end

  sig { params(args: T.untyped, kwargs: T.untyped).returns(String) }
  def root_url(*args, **kwargs); end

  # Sigs for route /auth/salesforce/callback(.:format)
  sig { params(args: T.untyped, kwargs: T.untyped).returns(String) }
  def auth_salesforce_callback_path(*args, **kwargs); end

  sig { params(args: T.untyped, kwargs: T.untyped).returns(String) }
  def auth_salesforce_callback_url(*args, **kwargs); end

  # Sigs for route /auth/stripe/callback(.:format)
  sig { params(args: T.untyped, kwargs: T.untyped).returns(String) }
  def auth_stripe_callback_path(*args, **kwargs); end

  sig { params(args: T.untyped, kwargs: T.untyped).returns(String) }
  def auth_stripe_callback_url(*args, **kwargs); end
end
