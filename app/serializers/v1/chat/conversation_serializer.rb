# frozen_string_literal: true

module V1
  module Chat
    class ConversationSerializer < Blueprinter::Base
      identifier :id

      view :default do
        fields :title, :archived_at, :agent_id, :created_at, :updated_at
      end

      view :extended do
        include_view :default

        field :messages_count do |conversation|
          conversation.messages.count
        end
      end
    end
  end
end
