# typed: true
# frozen_string_literal: true

# there are some "fake" classes used in the stripe types to provide
# types on subhash values coming from the api. If we don't define them
# `sigs` that contain them will throw an error. This file is to define
# these fake classes. The idea being they are safe to remove from the codebase
# assuming that the sigs using them are also removed.

class Stripe::SubscriptionSchedulePhase < Stripe::StripeObject; end
class Stripe::SubscriptionSchedulePhaseSubscriptionItem < Stripe::StripeObject; end
class Stripe::SubscriptionSchedulePhaseInvoiceItem < Stripe::StripeObject; end
class Stripe::RevenueContract < Stripe::StripeObject; end
class Stripe::RevenueContractItemsListOjbect < Stripe::StripeObject; end
class Stripe::RevenueContractItem < Stripe::StripeObject; end
