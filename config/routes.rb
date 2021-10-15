# frozen_string_literal: true
# typed: false
require 'resque/server'
require 'resque/scheduler/server'

Rails.application.routes.draw do
  default_url_options protocol: :https

  root to: redirect('/auth/salesforce')
  # post '/auth/:provider/callback', to: 'sessions#create'
  get '/auth/salesforce/callback', to: 'sessions#salesforce_callback'
  get '/auth/stripe/callback', to: 'sessions#stripe_callback'

  # TODO need basic auth
  # authenticated :admin, ->(u) { u.root? } do
  #   mount Resque::Server.new => "/resque-monitor", as: :resque_web
  # end
end
