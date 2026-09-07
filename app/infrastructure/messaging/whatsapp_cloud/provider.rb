# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Messaging
  module WhatsappCloud
    class Provider
      class RequestError < StandardError; end

      Credentials = Struct.new(:access_token, :phone_number_id, :graph_version, keyword_init: true)
      GRAPH_HOST = "https://graph.facebook.com"

      # @param [Credentials]
      def initialize(credentials:)
        @access_token    = credentials.access_token
        @phone_number_id = credentials.phone_number_id
        @graph_version   = credentials.graph_version.presence || "v21.0"
      end

      # @param [String]
      # @param [String]
      # @return [Hash]
      def send_message(to:, body:)
        post_json(
          "#{phone_path}/messages",
          messaging_product: "whatsapp",
          recipient_type:    "individual",
          to:                digits(to),
          type:              "text",
          text:              { body: body }
        )
      end

      # @param [String]
      # @param [String]
      # @param [String]
      # @param [String]
      # @param [IO, StringIO]
      # @return [Hash]
      def send_document(to:, body:, filename:, content_type:, io:)
        media_id = upload_media(io: io, filename: filename, content_type: content_type)
        post_json(
          "#{phone_path}/messages",
          messaging_product: "whatsapp",
          recipient_type:    "individual",
          to:                digits(to),
          type:              "document",
          document:          {
            id:       media_id,
            filename: filename,
            caption:  body
          }
        )
      end

      # @param [String]
      # @param [String]
      # @param [String, Array<String>]
      # @return [Hash]
      def send_media(to:, body:, media_url:)
        url = Array(media_url).first
        post_json(
          "#{phone_path}/messages",
          messaging_product: "whatsapp",
          recipient_type:    "individual",
          to:                digits(to),
          type:              "document",
          document:          {
            link:    url,
            caption: body
          }
        )
      end

      private

      def upload_media(io:, filename:, content_type:)
        payload = io.respond_to?(:read) ? io.read : io.to_s
        io.rewind if io.respond_to?(:rewind)

        response = post_multipart(
          "#{phone_path}/media",
          fields: { "messaging_product" => "whatsapp", "type" => content_type },
          file:   { name: "file", filename: filename, content_type: content_type, body: payload }
        )
        media_id = response["id"]
        raise RequestError, "WhatsApp media upload returned no id" if media_id.blank?

        media_id
      end

      def post_json(path, payload)
        uri = graph_uri(path)
        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{@access_token}"
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(payload)
        parse_response(perform(uri, request))
      end

      def post_multipart(path, fields:, file:)
        uri = graph_uri(path)
        boundary = "----Findu#{SecureRandom.hex(8)}"
        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{@access_token}"
        request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
        request.body = multipart_body(boundary, fields, file)
        parse_response(perform(uri, request))
      end

      def multipart_body(boundary, fields, file)
        parts = fields.map do |name, value|
          "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{name}\"\r\n\r\n#{value}\r\n"
        end
        parts << "--#{boundary}\r\n" \
                 "Content-Disposition: form-data; name=\"#{file[:name]}\"; filename=\"#{file[:filename]}\"\r\n" \
                 "Content-Type: #{file[:content_type]}\r\n\r\n"
        "#{parts.join}#{file[:body]}\r\n--#{boundary}--\r\n"
      end

      def perform(uri, request)
        Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
      end

      def parse_response(response)
        body = response.body.to_s
        json = body.present? ? JSON.parse(body) : {}
        unless response.is_a?(Net::HTTPSuccess)
          message = json.dig("error", "message") || body.presence || response.code
          raise RequestError, "WhatsApp Cloud API #{response.code}: #{message}"
        end

        json
      end

      def graph_uri(path)
        URI("#{GRAPH_HOST}/#{@graph_version}/#{path.delete_prefix('/')}")
      end

      def phone_path
        @phone_number_id
      end

      def digits(phone)
        Support::Phone.e164(phone).to_s.delete_prefix("+")
      end
    end
  end
end
