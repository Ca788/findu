require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Findu
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # Civil dates (Date.current, recurrence materialization) use Brazil timezone.
    config.time_zone = "America/Sao_Paulo"
    config.eager_load_paths << Rails.root.join("app", "domain")
    config.eager_load_paths << Rails.root.join("app", "infrastructure")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # Use Sidekiq as the ActiveJob backend
    config.active_job.queue_adapter = :sidekiq

    config.action_cable.worker_pool_size = ENV.fetch("ACTION_CABLE_WORKER_POOL_SIZE", 4).to_i

    # Use UUID as default primary key
    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
    end
  end
end
