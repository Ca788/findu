# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Chat::ProcessMessageUseCase do
  subject(:use_case) do
    described_class.new(
      transcriber:         transcriber,
      receipt_extractor:   receipt_extractor,
      answerer:            answerer
    )
  end

  let(:user)         { create(:user) }
  let(:conversation) { create(:chat_conversation, user: user) }
  let(:message)      { create(:chat_message, conversation: conversation, user: user, body: "Oi") }
  let(:transcriber)  { instance_double(UseCase::Chat::TranscribeMessageUseCase) }
  let(:receipt_extractor) { instance_double(UseCase::Chat::ExtractReceiptUseCase, call: []) }
  let(:answerer)     { instance_double(UseCase::Chat::AnswerConversationallyUseCase) }

  let(:assistant_reply) do
    build_stubbed(:chat_message, conversation: conversation, user: user, role: "assistant", status: "completed", body: "ok!")
  end

  before do
    allow(answerer).to receive(:call).and_return(assistant_reply)
  end

  describe "#call" do
    it "marks user message as completed and broadcasts" do
      use_case.call(message: message)

      expect(message.reload).to have_attributes(status: "completed")
    end

    it "delegates the assistant reply to the answerer with empty side_facts when no image" do
      use_case.call(message: message)

      expect(answerer).to have_received(:call).with(hash_including(user_message: message, side_facts: []))
    end

    context "when an error is raised mid-processing" do
      before do
        allow(answerer).to receive(:call).and_raise(StandardError, "boom")
      end

      it "marks the message as failed and re-raises" do
        expect { use_case.call(message: message) }.to raise_error(StandardError, "boom")
        expect(message.reload).to have_attributes(status: "failed")
        expect(message.error["message"]).to eq("boom")
      end
    end
  end
end
