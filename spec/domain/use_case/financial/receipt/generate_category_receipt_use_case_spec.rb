# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::Receipt::GenerateCategoryReceiptUseCase do
  subject(:use_case) { described_class.new }

  let(:user)      { create(:user) }
  let(:other)     { create(:user) }
  let(:month)     { Date.new(2026, 8, 1) }
  let(:groceries) do
    create(:financial_category, user: user, name: "Groceries", whatsapp: "+5511988887777")
  end

  before do
    create(:financial_transaction, :paid, user: user, category: groceries,
           transaction_type: "expense", amount: 250, competency_month: month)
    create(:financial_transaction, :pending, user: user, category: groceries,
           transaction_type: "expense", amount: 150, competency_month: month)
  end

  describe "#call" do
    it "creates a receipt with the paid total of the category" do
      receipt = use_case.call(user: user, category_id: groceries.id, from: "2026-08", to: "2026-08")

      expect(receipt).to be_persisted
      expect(receipt).to have_attributes(
        user_id:      user.id,
        category_id:  groceries.id,
        payer_phone:  groceries.whatsapp,
        payer_name:   "Groceries",
        period_start: month,
        period_end:   month,
        total_amount: 250,
        status:       "pending"
      )
    end

    it "attaches the rendered PDF" do
      receipt = use_case.call(user: user, category_id: groceries.id, from: "2026-08", to: "2026-08")

      expect(receipt.file).to be_attached
      expect(receipt.file.content_type).to eq("application/pdf")
      expect(receipt.file.download).to start_with("%PDF")
    end

    it "stores aggregation metadata" do
      receipt = use_case.call(user: user, category_id: groceries.id, from: "2026-08", to: "2026-08")

      expect(receipt.metadata).to include(
        "category_id"      => groceries.id,
        "status"           => "paid",
        "categories_count" => 1,
        "entries_count"    => 1
      )
    end

    it "swaps the period boundaries when they arrive inverted" do
      receipt = use_case.call(user: user, category_id: groceries.id, from: "2026-09", to: "2026-07")

      expect(receipt.period_start).to eq(Date.new(2026, 7, 1))
      expect(receipt.period_end).to eq(Date.new(2026, 9, 1))
    end

    it "raises when the category has no whatsapp" do
      groceries.update!(whatsapp: nil)

      expect {
        use_case.call(user: user, category_id: groceries.id, from: "2026-08")
      }.to raise_error(ArgumentError, /whatsapp/)
    end

    it "raises when the category has no paid transactions in the period" do
      expect {
        use_case.call(user: user, category_id: groceries.id, from: "2020-01", to: "2020-01")
      }.to raise_error(described_class::EmptyPeriodError)
    end

    it "ignores transactions from another user in the same category name" do
      foreign = create(:financial_category, user: other, name: "Groceries", whatsapp: "+5511999990000")
      create(:financial_transaction, :paid, user: other, category: foreign,
             transaction_type: "expense", amount: 5000, competency_month: month)

      receipt = use_case.call(user: user, category_id: groceries.id, from: "2026-08", to: "2026-08")

      expect(receipt.total_amount).to eq(250)
    end

    it "does not allow generating a receipt for another user's category" do
      expect {
        use_case.call(user: other, category_id: groceries.id, from: "2026-08")
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
