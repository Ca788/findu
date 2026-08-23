# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::Transaction::ListTransactionsByCategoryUseCase do
  subject(:use_case) { described_class.new }

  let(:user)      { create(:user) }
  let(:other)     { create(:user) }
  let(:month)     { Date.new(2026, 8, 1) }
  let(:groceries) { create(:financial_category, user: user, name: "Groceries") }
  let(:leisure)   { create(:financial_category, user: user, name: "Leisure") }

  describe "#call" do
    it "returns only transactions of the requested category" do
      wanted = create(:financial_transaction, :paid, user: user, category: groceries,
                      transaction_type: "expense", amount: 100, competency_month: month)
      create(:financial_transaction, :paid, user: user, category: leisure,
             transaction_type: "expense", amount: 200, competency_month: month)

      expect(use_case.call(user: user, category_id: groceries.id).to_a).to eq([wanted])
    end

    it "filters by competency range" do
      create(:financial_transaction, :paid, user: user, category: groceries,
             transaction_type: "expense", amount: 100, competency_month: month)
      recent = create(:financial_transaction, :paid, user: user, category: groceries,
                      transaction_type: "expense", amount: 300, competency_month: month.next_month)

      result = use_case.call(user: user, category_id: groceries.id, from: "2026-09", to: "2026-09")

      expect(result.to_a).to eq([recent])
    end

    it "filters by status" do
      create(:financial_transaction, :paid, user: user, category: groceries,
             transaction_type: "expense", amount: 100, competency_month: month)
      pending = create(:financial_transaction, :pending, user: user, category: groceries,
                       transaction_type: "expense", amount: 50, competency_month: month)

      result = use_case.call(user: user, category_id: groceries.id, status: "pending")

      expect(result.to_a).to eq([pending])
    end

    it "raises when the category belongs to another user" do
      foreign_category = create(:financial_category, user: other)

      expect {
        use_case.call(user: user, category_id: foreign_category.id)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "returns a relation that can be paginated" do
      create_list(:financial_transaction, 3, :paid, user: user, category: groceries,
                  transaction_type: "expense", competency_month: month)

      page = use_case.call(user: user, category_id: groceries.id).page(1).per(2)

      expect(page.size).to eq(2)
      expect(page.total_count).to eq(3)
    end
  end
end
