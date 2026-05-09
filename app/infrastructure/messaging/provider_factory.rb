# frozen_string_literal: true

module Messaging
  class ConfigurationError < StandardError; end

  class ProviderFactory
    SUPPORTED_PROVIDERS = %w[twilio].freeze

    # @return [Messaging::Provider]
    def self.build
      provider = ENV["MESSAGING_PROVIDER"].to_s.strip.downcase

      raise ConfigurationError, "MESSAGING_PROVIDER is not configured" if provider.empty?

      case provider
      when "twilio"
        credentials = Twilio::Provider::Credentials.new(
          account_sid:  ENV.fetch("TWILIO_ACCOUNT_SID"),
          auth_token:   ENV.fetch("TWILIO_AUTH_TOKEN"),
          phone_number: ENV.fetch("TWILIO_PHONE_NUMBER")
        )
        Twilio::Provider.new(credentials: credentials)
      else
        raise ConfigurationError,
              "Unsupported messaging provider: #{provider.inspect}. Supported: #{SUPPORTED_PROVIDERS.join(', ')}"
      end
    end
  end
end
