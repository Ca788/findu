# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::SummaryUseCase do
  subject(:use_case) { described_class.new }

  let(:user)       { create(:user) }
  let(:other_user) { create(:user) }
  let(:groceries)  { create(:financial_category, user: user, name: "Groceries") }
  let(:salary)     { create(:financial_category, user: user, name: "Salary") }

  let(:from) { Date.new(2026, 5, 1) }
  let(:to)   { Date.new(2026, 5, 31) }

  describe "#call" do
    before do
      create(:financial_transaction, :expense, user: user, category: groceries,
             amount: 100, occurred_at: Date.new(2026, 5, 5))
      create(:financial_transaction, :expense, user: user, category: groceries,
             amount: 50, occurred_at: Date.new(2026, 5, 10))
      create(:financial_transaction, :expense, user: user, category: nil,
             amount: 30, occurred_at: Date.new(2026, 5, 12))
      create(:financial_transaction, :income, user: user, category: salary,
             amount: 2000, occurred_at: Date.new(2026, 5, 1))

      create(:financial_transaction, :expense, user: user, category: groceries,
             amount: 999, occurred_at: Date.new(2026, 4, 30))

      create(:financial_transaction, :expense, user: other_user,
             amount: 999, occurred_at: Date.new(2026, 5, 5))
    end

    context "with a period and no other filters" do
      it "totals only transactions of the user inside the period" do
        result = use_case.call(user: user, from: from, to: to)

        expect(result.total_amount).to eq(2180)
        expect(result.transaction_count).to eq(4)
      end

      it "breaks down by transaction_type" do
        result = use_case.call(user: user, from: from, to: to)

        expect(result.by_type).to eq("expense" => 180, "income" => 2000)
      end

      it "breaks down by category, sorted desc, with Uncategorized for nil" do
        result = use_case.call(user: user, from: from, to: to)

        rows = result.by_category
        expect(rows.first.category_name).to eq("Salary")
        expect(rows.first.amount).to eq(2000)

        groceries_row = rows.find { |r| r.category_id == groceries.id }
        expect(groceries_row.amount).to eq(150)

        uncategorized = rows.find { |r| r.category_id.nil? }
        expect(uncategorized.category_name).to eq("Uncategorized")
        expect(uncategorized.amount).to eq(30)
      end
    end

    context "with transaction_type filter" do
      it "limits aggregations to that type" do
        result = use_case.call(user: user, from: from, to: to, transaction_type: "expense")

        expect(result.total_amount).to eq(180)
        expect(result.transaction_count).to eq(3)
        expect(result.by_type["income"]).to eq(0)
      end
    end

    context "with category_id filter" do
      it "limits aggregations to that category" do
        result = use_case.call(user: user, from: from, to: to, category_id: groceries.id)

        expect(result.total_amount).to eq(150)
        expect(result.transaction_count).to eq(2)
      end
    end

    context "without dates provided" do
      it "defaults to current month" do
        allow(Date).to receive(:current).and_return(Date.new(2026, 5, 15))

        result = use_case.call(user: user)

        expect(result.from).to eq(Date.new(2026, 5, 1))
        expect(result.to).to eq(Date.new(2026, 5, 31))
      end
    end

    context "when dates come as strings" do
      it "parses them" do
        result = use_case.call(user: user, from: "2026-05-01", to: "2026-05-31")

        expect(result.transaction_count).to eq(4)
      end
    end

    context "when there are no matching transactions" do
      it "returns zeros" do
        result = use_case.call(user: user, from: Date.new(2027, 1, 1), to: Date.new(2027, 1, 31))

        expect(result.total_amount).to eq(0)
        expect(result.transaction_count).to eq(0)
        expect(result.by_type).to eq("expense" => 0, "income" => 0)
        expect(result.by_category).to be_empty
      end
    end
  end
end
