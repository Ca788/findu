# frozen_string_literal: true

module Messaging
  class ProviderFactory
    # @return [Messaging::Provider]
    def self.build
      case ENV.fetch("MESSAGING_PROVIDER", "stub")
      when "twilio"
        credentials = Twilio::Provider::Credentials.new(
          account_sid:  ENV.fetch("TWILIO_ACCOUNT_SID"),
          auth_token:   ENV.fetch("TWILIO_AUTH_TOKEN"),
          phone_number: ENV.fetch("TWILIO_PHONE_NUMBER")
        )
        Twilio::Provider.new(credentials: credentials)
      else
        raise "Unsupported messaging provider: #{ENV['MESSAGING_PROVIDER']}"
      end
    end
  end
end
