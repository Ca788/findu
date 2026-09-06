# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::Category::ListCategoryTotalsUseCase do
  subject(:use_case) { described_class.new }

  let(:user)      { create(:user) }
  let(:other)     { create(:user) }
  let(:month)     { Date.new(2026, 8, 1) }
  let(:groceries) { create(:financial_category, user: user, name: "Groceries") }
  let(:salary)    { create(:financial_category, user: user, name: "Salary") }

  before do
    create(:financial_transaction, :paid, user: user, category: salary,
           transaction_type: "income", amount: 3000, competency_month: month)
    create(:financial_transaction, :paid, user: user, category: groceries,
           transaction_type: "expense", amount: 500, competency_month: month)
    create(:financial_transaction, :pending, user: user, category: groceries,
           transaction_type: "expense", amount: 300, competency_month: month)
  end

  describe "#call" do
    it "aggregates income, expense and balance per category" do
      totals = use_case.call(user: user, from: "2026-08", to: "2026-08")

      groceries_row = totals.find { |row| row.category_id == groceries.id }
      expect(groceries_row).to have_attributes(
        category_name:      "Groceries",
        income:             0,
        expense:            800,
        balance:            -800,
        paid_amount:        500,
        pending_amount:     300,
        transactions_count: 2
      )
    end

    it "sorts categories by gross movement descending" do
      totals = use_case.call(user: user, from: "2026-08", to: "2026-08")

      expect(totals.map(&:category_name)).to eq(%w[Salary Groceries])
    end

    it "groups transactions without a category under the uncategorized label" do
      create(:financial_transaction, :paid, user: user, category: nil,
             transaction_type: "expense", amount: 75, competency_month: month)

      totals = use_case.call(user: user, from: "2026-08", to: "2026-08")
      row    = totals.find { |item| item.category_id.nil? }

      expect(row.category_name).to eq(described_class::UNCATEGORIZED_LABEL)
      expect(row.expense).to eq(75)
    end

    it "excludes competency months outside the requested range" do
      create(:financial_transaction, :paid, user: user, category: groceries,
             transaction_type: "expense", amount: 999, competency_month: month.next_month)

      totals = use_case.call(user: user, from: "2026-08", to: "2026-08")

      expect(totals.find { |row| row.category_id == groceries.id }.expense).to eq(800)
    end

    it "never leaks another user's transactions" do
      foreign_category = create(:financial_category, user: other, name: "Groceries")
      create(:financial_transaction, :paid, user: other, category: foreign_category,
             transaction_type: "expense", amount: 999, competency_month: month)

      totals = use_case.call(user: user, from: "2026-08", to: "2026-08")

      expect(totals.map(&:category_id)).not_to include(foreign_category.id)
      expect(totals.sum(&:total)).to eq(3800)
    end

    it "filters by transaction type" do
      totals = use_case.call(user: user, from: "2026-08", to: "2026-08", transaction_type: "income")

      expect(totals.map(&:category_id)).to eq([salary.id])
    end

    it "filters by category" do
      totals = use_case.call(user: user, from: "2026-08", to: "2026-08", category_id: groceries.id)

      expect(totals.map(&:category_id)).to eq([groceries.id])
      expect(totals.first.expense).to eq(800)
    end

    it "filters by payer phone" do
      create(:financial_transaction, :paid, user: user, category: groceries,
             transaction_type: "expense", amount: 40,
             competency_month: month, payer_phone: "+5511988887777")

      totals = use_case.call(user: user, from: "2026-08", to: "2026-08", payer_phone: "+5511988887777")

      expect(totals.size).to eq(1)
      expect(totals.first.expense).to eq(40)
    end

    it "returns an empty array when there is nothing in the period" do
      expect(use_case.call(user: user, from: "2020-01", to: "2020-01")).to eq([])
    end
  end
end
