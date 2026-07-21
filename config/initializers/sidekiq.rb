redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

redis_config = {
  url: redis_url,
  network_timeout: 5,
  pool_timeout: 5,
  size: Integer(ENV.fetch("REDIS_POOL_SIZE", ENV.fetch("SIDEKIQ_CONCURRENCY", "5"))) + 2
}

Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config.merge(
    size: Integer(ENV.fetch("REDIS_CLIENT_POOL_SIZE", "3"))
  )
end
