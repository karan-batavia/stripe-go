# typed: true
# frozen_string_literal: true

Sentry.init do |config|
  config.logger = Integrations::Log.log
  config.dsn = ENV.fetch('SENTRY_DSN')
  config.traces_sample_rate = 0.5
  config.breadcrumbs_logger = [:sentry_logger, :http_logger]
  config.enabled_environments = %w{production staging}
  config.excluded_exceptions = []

  # `drain_and_shutdown` allows us to async report errors, otherwise we'd need to report them sync
  # config.background_worker_threads = 0

  # `DYNO` is formatted as `worker.12`, `scheduler.1`, etc
  config.server_name = ENV.fetch('DYNO')[/[^.]+/, 0] if ENV['DYNO']
end

# https://github.com/getsentry/sentry-ruby/issues/1612
Sentry::BackgroundWorker.class_eval do
  def drain_and_shutdown(timeout=1)
    T.bind(self, Sentry::BackgroundWorker)

    return if @executor.class != Concurrent::ThreadPoolExecutor

    @executor.shutdown
    return if @executor.wait_for_termination(timeout)
    @executor.kill
  end
end
