# frozen_string_literal: true

require "open-uri"

module Messaging
  module Twilio
    class Provider
      Credentials = Struct.new(:account_sid, :auth_token, :phone_number, keyword_init: true)

      # @param [Credentials] credentials
      # @param [SignatureValidator] signature_validator
      def initialize(credentials:, signature_validator: nil)
        @credentials        = credentials
        @signature_validator = signature_validator || SignatureValidator.new(auth_token: credentials.auth_token)
      end

      # @param [ActionController::Parameters, Hash]
      # @return [Messaging::Message]
      def parse(params)
        raw_from = params[:From].to_s
        Message.new(
          from:     normalize_phone(raw_from),
          reply_to: raw_from,
          body:     params[:Body].to_s.strip,
          media:    extract_media(params),
          raw:      params
        )
      end

      # @param [String]
      # @param [String]
      # @return [Hash]
      def fetch_media(url:, content_type:)
        ext      = Rack::Mime::MIME_TYPES.invert[content_type] || ".bin"
        media_sid = URI.parse(url).path.split("/").last
        tempfile  = Tempfile.new(["twilio_media", ext], binmode: true)

        URI.open(url, http_basic_authentication: [@credentials.account_sid, @credentials.auth_token]) do |io|
          tempfile.write(io.read)
        end
        tempfile.rewind

        { io: tempfile, filename: "#{media_sid}#{ext}", content_type: content_type }
      rescue OpenURI::HTTPError, IOError, SocketError => e
        raise Messaging::MediaFetchError, "Failed to fetch Twilio media: #{e.message}"
      end

      # @param [ActionDispatch::Request]
      # @param [Hash]
      # @return [Boolean]
      def valid_signature?(request, params)
        @signature_validator.valid?(request, params)
      end

      # @param [String]
      # @param [String]
      # @return [void]
      def send_message(to:, body:)
        client.messages.create(from: sender_number, to: to, body: body)
      end

      private

      def extract_media(params)
        (0...params[:NumMedia].to_i).map do |i|
          { url: params[:"MediaUrl#{i}"].to_s, content_type: params[:"MediaContentType#{i}"].to_s }
        end
      end

      def normalize_phone(phone)
        phone.delete_prefix("whatsapp:")
      end

      def client
        ::Twilio::REST::Client.new(@credentials.account_sid, @credentials.auth_token)
      end

      def sender_number
        number = @credentials.phone_number
        number.start_with?("whatsapp:") ? number : "whatsapp:#{number}"
      end
    end
  end
end
