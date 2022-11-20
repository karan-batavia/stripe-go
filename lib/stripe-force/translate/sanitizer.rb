# frozen_string_literal: true
# typed: true

module StripeForce
  module Sanitizer
    extend T::Sig
    include Integrations::Log
    include StripeForce::Constants

    def self.sanitize(stripe_record)
      if stripe_record.is_a?(Stripe::Customer)
        sanitize_customer(stripe_record)
      end

      if stripe_record.is_a?(Stripe::Price)
        sanitize_price(stripe_record)
      end

      # values are stored as decimals in Salesforce
      if stripe_record.is_a?(Stripe::Coupon)
        sanitize_coupon(stripe_record)
      end
    end

    private_class_method def self.sanitize_coupon(stripe_coupon)
      if stripe_coupon[:amount_off]
        stripe_coupon[:amount_off] = stripe_coupon[:amount_off].to_i

        # TODO remove this once we add the currency field to the Stripe object
        stripe_coupon[:currency] = "USD"
      end
    end

    private_class_method def self.sanitize_price(stripe_price)
      if stripe_price[:unit_amount_decimal] && !Integrations::Utilities::StripeUtil.is_integer_value?(stripe_price[:unit_amount_decimal])
        # Stripe only supports 12 digits
        stripe_price[:unit_amount_decimal] = stripe_price[:unit_amount_decimal].round(MAX_STRIPE_PRICE_PRECISION)
      end
    end

    private_class_method def self.sanitize_customer(stripe_customer)
      if stripe_customer[:description]
        stripe_customer[:description] = stripe_customer[:description][0..349]
      end

      if stripe_customer[:shipping] && stripe_customer[:shipping][:phone]
        stripe_customer[:shipping][:phone] = stripe_customer[:shipping][:phone][0..19]
      end

      # passing a partial shipping hash will trigger an error, remove the shipping hash entirely if it's only partial
      if !stripe_customer.shipping.respond_to?(:address) || stripe_customer.shipping.address.to_h.empty?
        log.info 'no address on shipping hash, removing'
        stripe_customer.shipping = {}
      end
    end
  end
end
