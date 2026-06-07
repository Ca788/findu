# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Chat::ProcessMessageUseCase do
  subject(:use_case) do
    described_class.new(
      classifier:            classifier,
      transcriber:           transcriber,
      transaction_extractor: transaction_extractor,
      answerer:              answerer
    )
  end

  let(:user)         { create(:user) }
  let(:conversation) { create(:chat_conversation, user: user) }
  let(:message)      { create(:chat_message, conversation: conversation, user: user, body: "gastei 50 no mercado") }
  let(:classifier)   { instance_double(UseCase::Chat::ClassifyIntentUseCase) }
  let(:transcriber)  { instance_double(UseCase::Chat::TranscribeMessageUseCase) }
  let(:transaction_extractor) { instance_double(UseCase::Messaging::ExtractTransactionFromMessageUseCase) }
  let(:answerer) { instance_double(UseCase::Chat::AnswerConversationallyUseCase) }

  let(:assistant_reply) do
    build_stubbed(:chat_message, conversation: conversation, user: user, role: "assistant", status: "completed", body: "ok!")
  end

  before do
    allow(answerer).to receive(:call).and_return(assistant_reply)
  end

  describe "#call" do
    context "when intent is create_transaction with valid extraction" do
      let(:extraction_result) do
        UseCase::Messaging::ExtractTransactionFromMessageUseCase::Result.new(
          amount:           BigDecimal("50.00"),
          transaction_type: "expense",
          description:      "mercado",
          occurred_at:      Time.current,
          confidence:       0.9
        )
      end

      before do
        allow(classifier).to receive(:call).and_return(
          UseCase::Chat::ClassifyIntentUseCase::Result.new(intent: "create_transaction", confidence: 0.9)
        )
        allow(transaction_extractor).to receive(:call).and_return(extraction_result)
      end

      it "creates a Financial::Transaction for the user" do
        expect { use_case.call(message: message) }.to change(user.transactions, :count).by(1)
      end

      it "marks the user message as completed with intent create_transaction" do
        use_case.call(message: message)

        expect(message.reload).to have_attributes(status: "completed", intent: "create_transaction")
        expect(message.payload["transaction_id"]).to be_present
      end

      it "delegates the assistant reply to the answerer with side_facts" do
        use_case.call(message: message)

        expect(answerer).to have_received(:call).with(
          hash_including(user_message: message, side_facts: array_including(a_string_matching(/registrei despesa/)))
        )
      end
    end

    context "when classifier returns low confidence" do
      before do
        allow(classifier).to receive(:call).and_return(
          UseCase::Chat::ClassifyIntentUseCase::Result.new(intent: "create_transaction", confidence: 0.1)
        )
      end

      it "treats intent as unknown" do
        use_case.call(message: message)

        expect(message.reload).to have_attributes(status: "completed", intent: "unknown")
      end

      it "does not create any transaction" do
        expect { use_case.call(message: message) }.not_to change(Financial::Transaction, :count)
      end

      it "delegates the assistant reply to the answerer with empty side_facts" do
        use_case.call(message: message)

        expect(answerer).to have_received(:call).with(hash_including(user_message: message, side_facts: []))
      end
    end

    context "when classifier returns unknown" do
      before do
        allow(classifier).to receive(:call).and_return(
          UseCase::Chat::ClassifyIntentUseCase::Result.new(intent: "unknown", confidence: 0.9)
        )
      end

      it "delegates the assistant reply to the answerer without side_facts" do
        use_case.call(message: message)

        expect(answerer).to have_received(:call).with(hash_including(user_message: message, side_facts: []))
      end
    end

    context "when an error is raised mid-processing" do
      before do
        allow(classifier).to receive(:call).and_raise(StandardError, "boom")
      end

      it "marks the message as failed and re-raises" do
        expect { use_case.call(message: message) }.to raise_error(StandardError, "boom")
        expect(message.reload).to have_attributes(status: "failed")
        expect(message.error["message"]).to eq("boom")
      end
    end
  end
end
