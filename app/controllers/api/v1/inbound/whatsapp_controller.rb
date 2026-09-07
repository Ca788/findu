# frozen_string_literal: true

module Api
  module V1
    module Inbound
      class WhatsappController < ActionController::API

        def verify
          mode      = params["hub.mode"]
          token     = params["hub.verify_token"]
          challenge = params["hub.challenge"]

          if mode == "subscribe" && token.present? && ActiveSupport::SecurityUtils.secure_compare(token, verify_token)
            return render plain: challenge, status: :ok
          end

          head :forbidden
        end

        def receive
          Rails.logger.info("[whatsapp.webhook] #{request.raw_post.to_s.truncate(2000)}")
          head :ok
        end

        private

        def verify_token
          ENV["WHATSAPP_VERIFY_TOKEN"].to_s
        end
      end
    end
  end
end
