require 'dotenv/load'

require 'rubygems'
require 'bundler'

module StripeForce

end

Bundler.require(:default, :development)

# CREATE DATABASE stripeforce
DB = Sequel.connect(ENV.fetch('DATABASE'))

Restforce.configure do |config|
  config.log_level = :debug
  # config.log = true
end

# really? Can't set this on an instance or `configure` level?
Restforce.log = ENV.fetch('SALESFORCE_LOG', 'false') == 'true'

require_relative 'user'
require_relative 'translate'
require_relative 'polling'
