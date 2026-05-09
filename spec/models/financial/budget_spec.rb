# frozen_string_literal: true

require "rails_helper"

RSpec.describe Financial::Budget do
  let(:user) { create(:user) }
  let(:budget) do
    create(:financial_budget, user: user,
           period_start: Date.new(2026, 5, 1),
           period_end:   Date.new(2026, 5, 31),
           limit_amount: 1000)
  end

  describe "validations" do
    it "is invalid without limit_amount" do
      record = build(:financial_budget, user: user, limit_amount: nil)

      expect(record).not_to be_valid
      expect(record.errors[:limit_amount]).to include("can't be blank")
    end

    it "is invalid when period_end equals period_start" do
      record = build(:financial_budget, user: user,
                     period_start: Date.new(2026, 5, 1),
                     period_end:   Date.new(2026, 5, 1))

      expect(record).not_to be_valid
    end
  end

  describe "consumption" do
    before do
      create(:financial_transaction, :expense, user: user, amount: 100,
             occurred_at: Date.new(2026, 5, 5))
      create(:financial_transaction, :expense, user: user, amount: 80,
             occurred_at: Date.new(2026, 5, 20))

      create(:financial_transaction, :income, user: user, amount: 5000,
             occurred_at: Date.new(2026, 5, 10))

      create(:financial_transaction, :expense, user: user, amount: 999,
             occurred_at: Date.new(2026, 4, 30))
      create(:financial_transaction, :expense, user: user, amount: 999,
             occurred_at: Date.new(2026, 6, 1))

      other_user = create(:user)
      create(:financial_transaction, :expense, user: other_user, amount: 999,
             occurred_at: Date.new(2026, 5, 10))
    end

    describe "#spent_amount" do
      it "sums only expense transactions of the owner inside the period" do
        expect(budget.spent_amount).to eq(180)
      end

      it "ignores income transactions inside the period" do
        income_only_user   = create(:user)
        income_only_budget = create(:financial_budget, user: income_only_user,
                                    period_start: Date.new(2026, 5, 1),
                                    period_end:   Date.new(2026, 5, 31),
                                    limit_amount: 1000)
        create(:financial_transaction, :income, user: income_only_user, amount: 5000,
               occurred_at: Date.new(2026, 5, 10))

        expect(income_only_budget.spent_amount).to eq(0)
      end

      it "memoizes the result on the instance" do
        budget.spent_amount

        expect(user.transactions).not_to receive(:where)
        budget.spent_amount
      end
    end

    describe "#remaining" do
      it "returns limit_amount - spent_amount" do
        expect(budget.remaining).to eq(820)
      end

      it "can go negative when overspent" do
        create(:financial_transaction, :expense, user: user, amount: 2000,
               occurred_at: Date.new(2026, 5, 15))
        budget.reload_usage

        expect(budget.remaining).to eq(-1180)
      end
    end

    describe "#usage_percent" do
      it "returns the percentage of the limit consumed, rounded to 2 decimals" do
        expect(budget.usage_percent).to eq(18.0)
      end

      it "returns 0.0 when limit_amount is zero" do
        allow(budget).to receive(:limit_amount).and_return(0)

        expect(budget.usage_percent).to eq(0.0)
      end
    end

    describe "#reload_usage" do
      it "busts the memoized spent_amount cache" do
        expect(budget.spent_amount).to eq(180)

        create(:financial_transaction, :expense, user: user, amount: 50,
               occurred_at: Date.new(2026, 5, 25))

        expect(budget.spent_amount).to eq(180)
        expect(budget.reload_usage.spent_amount).to eq(230)
      end
    end
  end
end
