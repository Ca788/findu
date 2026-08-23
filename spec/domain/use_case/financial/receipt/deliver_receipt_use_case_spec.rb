# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::Receipt::DeliverReceiptUseCase do
  subject(:use_case) { described_class.new(provider: provider) }

  let(:provider) { instance_double("Messaging::Twilio::Provider", send_media: true) }
  let(:receipt)  { create(:financial_receipt, :with_file, payer_name: "Maria", total_amount: 400) }

  before do
    allow(receipt.file).to receive(:url).and_return("https://files.example.com/comprovante.pdf")
  end

  describe "#call" do
    it "sends the PDF to the payer over WhatsApp" do
      use_case.call(receipt: receipt)

      expect(provider).to have_received(:send_media).with(
        to:        receipt.payer_phone,
        body:      a_string_including("Maria").and(a_string_including("R$400,00")),
        media_url: "https://files.example.com/comprovante.pdf"
      )
    end

    it "marks the receipt as sent" do
      expect { use_case.call(receipt: receipt) }
        .to change { receipt.reload.status }.from("pending").to("sent")

      expect(receipt.sent_at).to be_present
    end

    it "raises when the receipt has no rendered file" do
      empty = create(:financial_receipt)

      expect { use_case.call(receipt: empty) }.to raise_error(described_class::MissingFileError)
    end

    context "when the provider fails" do
      before { allow(provider).to receive(:send_media).and_raise(StandardError, "twilio down") }

      it "records the failure and re-raises" do
        expect { use_case.call(receipt: receipt) }.to raise_error(StandardError, "twilio down")

        receipt.reload
        expect(receipt.status).to eq("failed")
        expect(receipt.metadata["delivery_error"]).to eq("twilio down")
      end
    end
  end
end
