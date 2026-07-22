# frozen_string_literal: true

if ENV["DD_API_KEY"].present?
  require "datadog/auto_instrument"

  Datadog.configure do |c|
    c.service = ENV.fetch("DD_SERVICE", "findu-api")
    c.env = ENV.fetch("DD_ENV", Rails.env)
    c.version = ENV["DD_VERSION"] if ENV["DD_VERSION"].present?

    c.tracing.enabled = true
    c.tracing.instrument :rails
    c.tracing.instrument :active_record
    c.tracing.instrument :http
    c.tracing.instrument :redis
    c.tracing.instrument :sidekiq
  end
end
