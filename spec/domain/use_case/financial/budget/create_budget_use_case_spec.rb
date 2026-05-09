# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::Budget::CreateBudgetUseCase do
  subject(:use_case) { described_class.new }

  let(:user) { create(:user) }
  let(:valid_attributes) do
    {
      period_type:  "monthly",
      period_start: Date.new(2026, 5, 1),
      period_end:   Date.new(2026, 5, 31),
      limit_amount: 1500.00
    }
  end

  describe "#call" do
    context "when attributes are valid" do
      it "creates a Financial::Budget scoped to the user" do
        expect {
          use_case.call(user: user, attributes: valid_attributes)
        }.to change(user.budgets, :count).by(1)
      end

      it "returns a persisted budget with the given attributes" do
        budget = use_case.call(user: user, attributes: valid_attributes)

        expect(budget).to be_a(Financial::Budget)
        expect(budget).to be_persisted
        expect(budget).to have_attributes(
          user_id:      user.id,
          period_type:  "monthly",
          limit_amount: 1500.00
        )
      end
    end

    context "when attributes have unknown keys" do
      it "ignores keys outside of PERMITTED_ATTRIBUTES" do
        budget = use_case.call(
          user: user,
          attributes: valid_attributes.merge(user_id: SecureRandom.uuid, foo: "bar")
        )

        expect(budget.user_id).to eq(user.id)
      end
    end

    context "when attributes use string keys" do
      it "still creates the budget" do
        budget = use_case.call(user: user, attributes: valid_attributes.stringify_keys)

        expect(budget).to be_persisted
      end
    end

    context "when limit_amount is invalid" do
      it "raises ActiveRecord::RecordInvalid" do
        expect {
          use_case.call(user: user, attributes: valid_attributes.merge(limit_amount: 0))
        }.to raise_error(ActiveRecord::RecordInvalid, /Limit amount/)
      end
    end

    context "when period_end is not after period_start" do
      it "raises ActiveRecord::RecordInvalid" do
        expect {
          use_case.call(
            user: user,
            attributes: valid_attributes.merge(period_end: valid_attributes[:period_start])
          )
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
