# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::Budget::CheckBudgetConsumptionUseCase do
  subject(:use_case) { described_class.new }

  let(:user) { create(:user) }

  describe "#call" do
    context "when no budget covers the date" do
      it "returns an empty array" do
        expect(use_case.call(user: user, occurred_at: Time.current)).to eq([])
      end
    end

    context "when there is a budget but usage is below 80%" do
      it "returns an empty array" do
        create(:financial_budget, user: user, limit_amount: 1000)
        create(:financial_transaction, user: user, amount: 500, transaction_type: "expense", occurred_at: Date.current)

        expect(use_case.call(user: user, occurred_at: Time.current)).to eq([])
      end
    end

    context "when usage is between 80% and 100%" do
      it "returns a warning with status 'warning'" do
        budget = create(:financial_budget, user: user, limit_amount: 1000)
        create(:financial_transaction, user: user, amount: 850, transaction_type: "expense", occurred_at: Date.current)

        warnings = use_case.call(user: user, occurred_at: Time.current)

        expect(warnings.size).to eq(1)
        expect(warnings.first).to include(
          budget_id:     budget.id,
          limit_amount:  budget.limit_amount,
          usage_percent: 85.0,
          status:        "warning"
        )
      end
    end

    context "when usage exceeds 100%" do
      it "returns a warning with status 'exceeded' and negative remaining" do
        create(:financial_budget, user: user, limit_amount: 1000)
        create(:financial_transaction, user: user, amount: 1500, transaction_type: "expense", occurred_at: Date.current)

        warnings = use_case.call(user: user, occurred_at: Time.current)

        expect(warnings.first).to include(
          usage_percent: 150.0,
          status:        "exceeded"
        )
        expect(warnings.first[:remaining]).to eq(-500)
      end
    end

    context "when there are multiple covering budgets" do
      it "returns a warning per impacted budget only" do
        monthly = create(:financial_budget, user: user, limit_amount: 1000)
        yearly  = create(
          :financial_budget,
          :yearly,
          user:         user,
          limit_amount: 50_000,
          period_start: Date.current.beginning_of_year,
          period_end:   Date.current.end_of_year
        )
        create(:financial_transaction, user: user, amount: 900, transaction_type: "expense", occurred_at: Date.current)

        warnings = use_case.call(user: user, occurred_at: Time.current)

        warned_ids = warnings.map { |w| w[:budget_id] }
        expect(warned_ids).to include(monthly.id)
        expect(warned_ids).not_to include(yearly.id)
      end
    end

    context "when income transactions exist" do
      it "ignores income (only expense impacts the budget)" do
        create(:financial_budget, user: user, limit_amount: 1000)
        create(:financial_transaction, user: user, amount: 5000, transaction_type: "income", occurred_at: Date.current)

        expect(use_case.call(user: user, occurred_at: Time.current)).to eq([])
      end
    end

    context "when occurred_at is a string" do
      it "parses it and finds covering budgets" do
        create(:financial_budget, user: user, limit_amount: 1000)
        create(:financial_transaction, user: user, amount: 950, transaction_type: "expense", occurred_at: Date.current)

        warnings = use_case.call(user: user, occurred_at: Date.current.to_s)

        expect(warnings.size).to eq(1)
        expect(warnings.first[:status]).to eq("warning")
      end
    end

    context "isolation between users" do
      it "does not leak warnings from another user's budgets" do
        other_user = create(:user)
        create(:financial_budget, user: other_user, limit_amount: 1000)
        create(:financial_transaction, user: other_user, amount: 2000, transaction_type: "expense", occurred_at: Date.current)

        expect(use_case.call(user: user, occurred_at: Time.current)).to eq([])
      end
    end
  end
end
