# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::Budget::ListCurrentBudgetsUseCase do
  subject(:use_case) { described_class.new }

  let(:user) { create(:user) }

  describe "#call" do
    let!(:current_monthly) do
      create(:financial_budget, user: user,
             period_start: Date.new(2026, 5, 1),
             period_end:   Date.new(2026, 5, 31))
    end

    let!(:past_budget) do
      create(:financial_budget, user: user,
             period_start: Date.new(2026, 4, 1),
             period_end:   Date.new(2026, 4, 30))
    end

    let!(:foreign_budget) do
      other_user = create(:user)
      create(:financial_budget, user: other_user,
             period_start: Date.new(2026, 5, 1),
             period_end:   Date.new(2026, 5, 31))
    end

    context "when date is provided as String" do
      it "returns only budgets covering that date for the user" do
        result = use_case.call(user: user, date: "2026-05-15")

        expect(result.budgets.to_a).to eq([current_monthly])
        expect(result.reference_date).to eq(Date.new(2026, 5, 15))
      end
    end

    context "when date is provided as Date" do
      it "returns budgets covering it" do
        result = use_case.call(user: user, date: Date.new(2026, 5, 15))

        expect(result.budgets.to_a).to eq([current_monthly])
      end
    end

    context "when date is blank" do
      it "defaults to today" do
        allow(Date).to receive(:current).and_return(Date.new(2026, 5, 10))

        result = use_case.call(user: user, date: nil)

        expect(result.reference_date).to eq(Date.new(2026, 5, 10))
        expect(result.budgets.to_a).to eq([current_monthly])
      end
    end

    context "when date is unparseable" do
      it "falls back to today" do
        allow(Date).to receive(:current).and_return(Date.new(2026, 5, 10))

        result = use_case.call(user: user, date: "not-a-date")

        expect(result.reference_date).to eq(Date.new(2026, 5, 10))
      end
    end

    context "when no budget covers the date" do
      it "returns an empty relation" do
        result = use_case.call(user: user, date: "2027-01-01")

        expect(result.budgets.to_a).to be_empty
      end
    end
  end
end
