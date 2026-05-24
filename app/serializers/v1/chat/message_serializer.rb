# frozen_string_literal: true

module V1
  module Chat
    class MessageSerializer < Blueprinter::Base
      identifier :id

      view :default do
        fields :role, :kind, :body, :status, :intent, :conversation_id,
               :parent_message_id, :created_at, :updated_at
      end

      view :extended do
        include_view :default

        fields :payload, :error

        field :audio_url do |message|
          next nil unless message.audio.attached?

          Rails.application.routes.url_helpers.rails_blob_path(message.audio, only_path: true)
        end
      end
    end
  end
end
