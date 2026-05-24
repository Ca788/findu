# frozen_string_literal: true

FactoryBot.define do
  factory :chat_conversation, class: "Chat::Conversation" do
    user
    title { "Default" }
  end
end
