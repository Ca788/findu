# frozen_string_literal: true

module Messaging
  module Twilio
    class SignatureValidator
      # @param [String] auth_token
      def initialize(auth_token:)
        @auth_token = auth_token
      end

      # @param [ActionDispatch::Request]
      # @param [Hash] params
      # @return [Boolean]
      def valid?(request, params)
        validator = ::Twilio::Security::RequestValidator.new(@auth_token)
        validator.validate(webhook_url(request), params, signature(request))
      end

      private

      def webhook_url(request)
        proto = request.headers["X-Forwarded-Proto"].presence || request.scheme
        host  = request.headers["X-Forwarded-Host"].presence  || request.host
        "#{proto}://#{host}#{request.fullpath}"
      end

      def signature(request)
        request.headers["X-Twilio-Signature"].to_s
      end
    end
  end
end
