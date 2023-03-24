# frozen_string_literal: true
source 'https://rubygems.org'
git_source(:github) {|repo| "https://github.com/#{repo}.git" }

ruby '2.7.6'

gem 'sorbet', '~> 0.5.10477', group: :development
gem 'sorbet-runtime', '~> 0.5.10477', require: true
gem 'sorbet-rails', '~> 0.7.34'

# Force version dependents (to appease security audits)
gem 'sinatra', '~> 2.2.3' # resque dependent
gem 'rack', '>= 2.2.6.4'
gem 'activesupport', '~> 6.1.7'

# https://github.com/ruby/irb/issues/43
gem 'reline', '~> 0.3.1'

gem 'dotenv-rails', '2.8.1', groups: [:development, :test]
gem 'foreman', groups: [:development, :test]
gem 'rails', '~> 6.1.7.2'
gem 'lograge', '~> 0.12'

group :production do
  gem 'puma', '~> 5.6.5'
end

# sentry
gem "sentry-ruby", "~> 5.4.2"
gem "sentry-rails", "~> 5.4.2"
gem "sentry-resque", "~> 5.4.2"
gem 'simple_structured_logger', '~> 1.0.2'

# resque
gem 'resque', '~> 2.2.0'
gem 'resque-scheduler', "~> 4.6.0"
gem 'resque-retry', '~> 1.7.6'
gem 'resque-heroku-signals', '~> 2.2.0'
gem 'redis', '~> 4.5.1'

# database
gem 'pg', '~> 1.4.3'
gem 'sequel', '5.61.0'
gem 'aws-sdk-kms', '~> 1.42.0'

# auth
# TODO hack to get around https://github.com/realdoug/omniauth-salesforce/issues/31
gem 'omniauth-rails_csrf_protection', '~> 1.0.1'
gem 'omniauth-salesforce', github: 'accel-com/omniauth-salesforce'
gem 'omniauth-stripe'
gem 'omniauth-oauth2', '1.7.2'
gem 'rack-attack', '~> 6.6.1'

# translation
gem 'restforce', '~> 6.0.0'
gem 'stripe', '~> 7.1.0'
gem 'rest-client', '~> 2.1.0'
gem 'hash_diff', '~> 1.1.1'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.9.1', require: false

gem 'omniauth', '~> 2.1.0'

# CVE-2019-13117 https://github.com/sparklemotion/nokogiri/issues/1943
gem 'nokogiri', '>= 1.13.10'

# https://groups.google.com/g/rubyonrails-security/c/ce9PhUANQ6s
gem 'rails-html-sanitizer', '1.4.4'

group :test do
  gem 'bundler-audit', '~> 0.9.1', require: false
  gem 'brakeman', '~> 5.3.1', require: false

  gem 'minitest', '~> 5.16.3'
  gem 'minitest-ci', '~> 3.4.0'
  gem 'minitest-profile'
  gem 'minitest-reporters', '~> 1.5.0'
  gem 'minitest-rails', '~> 6.1.0'

  # feature test
  gem 'capybara', '~> 3.37.1'
  gem 'webdrivers', '~> 5.2.0'
  gem 'selenium-webdriver', '~> 4.5.0'
  gem 'capybara-screenshot', '~> 1.0.26'

  gem 'mocha', '~> 1.15'
  gem 'rack-test', '~> 2.0.2'
  gem 'database_cleaner', '~> 1.7.0'
  gem 'simplecov', '~> 0.21.2'
end

group :test, :development do
  gem 'pry', '~> 0.14.1'
  gem 'pry-stack_explorer', '~> 0.6.1'
  gem 'pry-nav', '~> 1.0.0'
  gem 'pry-rails', '~> 0.3.9'
  # https://github.com/SudhagarS/pry-state
  gem 'binding_of_caller', '~> 1.0.0'
end

group :development do
  gem 'pry-rescue', '~> 1.5.2'
  gem 'pry-remote', '~> 0.1.8'

  gem 'better_errors', '~> 2.9.1'

  gem 'listen'
  gem 'spring'

  # lock to an old version to align with pay-server
  gem 'rubocop', '0.89.1'
  gem 'rubocop-daemon', require: false
  gem 'rubocop-minitest', require: false
end
