# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::Receipt::GenerateCategoryReceiptUseCase do
  subject(:use_case) { described_class.new }

  let(:user)      { create(:user) }
  let(:other)     { create(:user) }
  let(:month)     { Date.new(2026, 8, 1) }
  let(:groceries) { create(:financial_category, user: user, name: "Groceries") }
  let(:payer_phone) { "+5511988887777" }

  before do
    create(:financial_transaction, :paid, user: user, category: groceries,
           transaction_type: "income", amount: 250, competency_month: month,
           payer_name: "Maria", payer_phone: payer_phone)
    create(:financial_transaction, :pending, user: user, category: groceries,
           transaction_type: "income", amount: 150, competency_month: month,
           payer_name: "Maria", payer_phone: payer_phone)
  end

  describe "#call" do
    it "creates a receipt totalling the payer's transactions in the period" do
      receipt = use_case.call(user: user, payer_phone: payer_phone, from: "2026-08", to: "2026-08")

      expect(receipt).to be_persisted
      expect(receipt).to have_attributes(
        user_id:      user.id,
        payer_phone:  payer_phone,
        payer_name:   "Maria",
        period_start: month,
        period_end:   month,
        total_amount: 400,
        status:       "pending"
      )
    end

    it "attaches the rendered PDF" do
      receipt = use_case.call(user: user, payer_phone: payer_phone, from: "2026-08", to: "2026-08")

      expect(receipt.file).to be_attached
      expect(receipt.file.content_type).to eq("application/pdf")
      expect(receipt.file.download).to start_with("%PDF")
    end

    it "stores aggregation metadata" do
      receipt = use_case.call(user: user, payer_phone: payer_phone, from: "2026-08", to: "2026-08")

      expect(receipt.metadata).to include("categories_count" => 1, "entries_count" => 2)
    end

    it "prefers the explicit payer name over the stored one" do
      receipt = use_case.call(user: user, payer_phone: payer_phone, payer_name: "Maria Silva",
                              from: "2026-08", to: "2026-08")

      expect(receipt.payer_name).to eq("Maria Silva")
    end

    it "swaps the period boundaries when they arrive inverted" do
      receipt = use_case.call(user: user, payer_phone: payer_phone, from: "2026-09", to: "2026-07")

      expect(receipt.period_start).to eq(Date.new(2026, 7, 1))
      expect(receipt.period_end).to eq(Date.new(2026, 9, 1))
    end

    it "raises when payer_phone is blank" do
      expect {
        use_case.call(user: user, payer_phone: "  ")
      }.to raise_error(ArgumentError)
    end

    it "raises when the payer has no transactions in the period" do
      expect {
        use_case.call(user: user, payer_phone: payer_phone, from: "2020-01", to: "2020-01")
      }.to raise_error(described_class::EmptyPeriodError)
    end

    it "ignores transactions from another user with the same payer phone" do
      create(:financial_transaction, :paid, user: other, transaction_type: "income",
             amount: 5000, competency_month: month, payer_phone: payer_phone)

      receipt = use_case.call(user: user, payer_phone: payer_phone, from: "2026-08", to: "2026-08")

      expect(receipt.total_amount).to eq(400)
    end

    it "filters by status when requested" do
      receipt = use_case.call(user: user, payer_phone: payer_phone,
                              from: "2026-08", to: "2026-08", status: "paid")

      expect(receipt.total_amount).to eq(250)
    end
  end
end
