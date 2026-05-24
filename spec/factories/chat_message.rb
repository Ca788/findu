# frozen_string_literal: true

FactoryBot.define do
  factory :chat_message, class: "Chat::Message" do
    conversation { association :chat_conversation, user: user }
    user
    role   { "user" }
    kind   { "text" }
    status { "pending" }
    body   { "gastei 50 no mercado" }
  end
end
