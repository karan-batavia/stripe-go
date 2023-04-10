# frozen_string_literal: true
# typed: true

# more simple log formatting
SimpleStructuredLogger.logger.formatter = proc do |severity, _datetime, _progname, msg|
  "#{severity}: #{msg}\n"
end

SimpleStructuredLogger.configure do
  T.bind(self, SimpleStructuredLogger::Configuration)

  expand_log do |tags|
    if tags[:salesforce_object] && tags[:salesforce_object].is_a?(Restforce::SObject)
      salesforce_object = tags.delete(:salesforce_object)
      tags[:sf_object_id] = salesforce_object.Id
      tags[:sf_object_type] = salesforce_object.sobject_type
    end

    if tags[:stripe_resource] && tags[:stripe_resource].respond_to?(:id)
      stripe_resource = tags.delete(:stripe_resource)
      tags[:stripe_resource_id] = stripe_resource.id
      tags[:stripe_resource_type] = stripe_resource.class.to_s
    end

    if tags[:metric]
      Integrations::Metrics::Writer.instance.track_counter(tags[:metric], dimensions: tags)
    end

    tags
  end
end

# use a separate module so we can easily swap out the logger in the future
module Integrations
  module Log
    include SimpleStructuredLogger

    def self.included(klass)
      klass.class_eval do
        def self.log
          SimpleStructuredLogger::Writer.instance
        end
      end
    end
  end
end
