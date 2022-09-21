#!/usr/bin/env bundle exec ruby
# Description: setup a REPL with a SF user and example records ready to go
# frozen_string_literal: true
# typed: true

require File.expand_path('../config/environment', __dir__)

include StripeForce::Constants

if ARGV[0]
  prefix = "SF_#{ARGV[0].upcase}_"
else
  prefix = "SF_"
end

user = StripeForce::User.find(salesforce_account_id: ENV.fetch(prefix + 'INSTANCE_ID'))

if user
  puts "Using local user reference"
end

# most likely, the local creds will be expired
user ||= StripeForce::User.new(
  salesforce_account_id: ENV.fetch(prefix + 'INSTANCE_ID'),
  salesforce_token: ENV.fetch(prefix + 'ACCESS_TOKEN'),
  salesforce_refresh_token: ENV[prefix + 'REFRESH_TOKEN'],
  salesforce_instance_url: "https://#{ENV.fetch(prefix + 'INSTANCE_DOMAIN')}.my.salesforce.com",

  stripe_account_id: ENV.fetch('STRIPE_ACCOUNT_ID')
)

if user.salesforce_instance_url.blank?
  puts "ERROR: invalid instance URL, local user may be corrupted"
end

@user = user
@sf = sf = user.sf_client

def translate_order(order_id)
  locker = Integrations::Locker.new(@user)
  sf_order = @sf.find(SF_ORDER, order_id)
  StripeForce::Translate.perform(user: @user, sf_object: sf_order, locker: locker)
end

def loud_sf_logging
  ENV['SALESFORCE_LOG'] = 'true'
  @user.refresh
  @sf = sf = @user.sf_client
end

def example_sf_order
  sf_get(@sf.query("SELECT Id FROM #{SF_ORDER} ORDER BY CreatedDate DESC LIMIT 1").first.Id)
end

def example_sf_customer
  sf_get(@sf.query("SELECT Id FROM #{SF_ACCOUNT} ORDER BY CreatedDate DESC LIMIT 1").first.Id)
end

def example_sf_quote
  sf_get(@sf.query("SELECT Id FROM #{SF_ORDER_QUOTE} ORDER BY CreatedDate DESC LIMIT 1").first.Id)
end

def example_sf_product
  sf_get(@sf.query("SELECT Id FROM #{SF_PRODUCT} ORDER BY CreatedDate DESC LIMIT 1").first.Id)
end

def example_sf_pricebook
  sf_get(@sf.query("SELECT Id FROM #{SF_PRICEBOOK_ENTRY} ORDER BY CreatedDate DESC LIMIT 1").first.Id)
end

def example_stripe_subscription_schedule
  Stripe::SubscriptionSchedule.list({}, @user.stripe_credentials).data.sample
end

def wipe_record_tree(order_id)
  order = sf.find(SF_ORDER, order_id)

  account = sf.find(SF_ACCOUNT, order.AccountId)
end

def delete_sync_records
  result = @sf.query("SELECT Id FROM Sync_Record__c")
  result.each do |sync_record|
    puts "destroying\t#{sync_record.Id}"
    sync_record.destroy
  end
end

# we know the quote of the initial order will be 1:1 linked on the contract
# if this does not return a valid ID, it means the order is an amendment
def contract_id_from_initial_order(sf_initial_order_id)
  @sf.query(
    <<~EOL
      SELECT Id
      FROM #{SF_CONTRACT}
      WHERE SBQQ__Quote__c IN (SELECT SBQQ__Quote__c FROM #{SF_ORDER} WHERE Id = '#{sf_initial_order_id}')
    EOL
  ).first.Id
end

# given a contract ID, get all orders which amend that contract
def order_amendments_from_contract_id(sf_contract_id)
  @sf.query(
    <<~EOL
      SELECT Id, Type
      FROM #{SF_ORDER}
      WHERE Opportunity.SBQQ__AmendedContract__r.#{SF_CONTRACT_QUOTE_ID} = '#{sf_contract_id}'
    EOL
  )
end

# TODO this doesn't seem like it works on some accounts
# https://salesforce.stackexchange.com/questions/186025/how-to-we-get-list-of-installed-packages-and-it-version-number
# sf.query("SELECT Id FROM InstalledSubscriberPackage")

# TODO determine what users have the permission set assigned
# u.sf_client.query("SELECT Id, AssigneeId, Assignee.Name FROM PermissionSetAssignment WHERE PermissionSet.Name = 'Stripe_Connector_Integration_User'")

# dig into field level permissions "Field Permissions"
# u.sf_client.api_get 'sobjects/'
def get_fields_for_object(object_name)
  description = @sf.describe(object_name)
  description['fields'].map(&:name)
end

def get_all(object_name)
  all_fields = get_fields_for_object(object_name).join(',')
  sf.query("SELECT #{all_fields} FROM #{object_name}")
end

# or `sfdx force:limits:api:display -u mbianco+cpqpackage@stripe.com`
def user_limits(user)
  user.sf_client.limits.slice(*%w{DailyApiRequests DailyAsyncApexExecutions DailyBulkApiBatches DailyFunctionsApiCallLimit DailyStreamingApiEvents})
end

# new scratch orgs come without pricebooks active, this causes issues with amendments
def activate_pricebooks
  @sf.query("SELECT Id, Name, IsActive FROM #{SF_PRICEBOOK}").each do |sf_pricebook|
    next if sf_pricebook.IsActive

    @sf.update!(SF_PRICEBOOK, {
      SF_ID => sf_pricebook.Id,
      'IsActive' => true
    })
  end
end

def touch_order(sf_order)
  if sf_order.Description.present?
    raise "description is not empty"
  end

  @sf.update!(SF_ORDER, {
    SF_ID => sf_order.Id,
    "Description" => "stripe-force: #{Time.now.to_i}"
  })
end

def ensure_order_is_included_in_custom_where_clause(sf_order_or_id)
  sf_order = if sf_order_or_id.is_a?(String)
    sf_get(sf_order_or_id)
  else
    sf_order_or_id
  end

  order_poller = StripeForce::OrderPoller.new(@user)
  custom_soql = order_poller.send(:user_specified_where_clause_for_object)
  results = @sf.query("SELECT Id FROM #{SF_ORDER} WHERE Id = '#{sf_order.Id}' " + custom_soql)

  if results.first.blank?
    puts "Order is not included in custom soql"
  else
    puts "Order is included in custom soql"
  end
end

def has_cpq_installed?
  sf_client.query("SELECT COUNT() FROM PackageLicense WHERE NamespacePrefix LIKE 'SBQQ%'").count >= 1
end

# TODO make limit pages into some sort of helper
# https://appiphony92-dev-ed.lightning.force.com/lightning/setup/CompanyProfileInfo/home
# https://appiphony92-dev-ed.lightning.force.com/lightning/setup/CompanyResourceDisk/home

require_relative '../test/support/salesforce_debugging'
include SalesforceDebugging

user_info = sf.user_info

puts "Salesforce account information:"
puts user_info['username']
puts user_info['urls']['custom_domain']

Pry.start
