# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::Recurrence::MaterializeRecurrenceRuleUseCase do
  subject(:use_case) { described_class.new }

  let(:user) { create(:user) }

  it "creates pending transactions for the next 12 months by default" do
    travel_to(Time.zone.local(2026, 8, 15, 12, 0)) do
      rule = create(:financial_recurrence_rule, user: user,
                    starts_on: Date.new(2026, 8, 1), amount: 200, description: "Internet")

      created = use_case.call(rule: rule)

      expect(created).to eq(13) # ago/2026 até ago/2027 = 13 meses
      expect(rule.transactions.count).to eq(13)
      expect(rule.transactions.pluck(:status).uniq).to eq(["pending"])
    end
  end

  it "is idempotent: does not duplicate existing months" do
    travel_to(Time.zone.local(2026, 8, 15, 12, 0)) do
      rule = create(:financial_recurrence_rule, user: user,
                    starts_on: Date.new(2026, 8, 1), amount: 200)

      use_case.call(rule: rule)
      created_again = use_case.call(rule: rule)

      expect(created_again).to eq(0)
      expect(rule.transactions.count).to eq(13)
    end
  end

  it "stops at ends_on when defined" do
    travel_to(Time.zone.local(2026, 8, 15, 12, 0)) do
      rule = create(:financial_recurrence_rule, user: user,
                    starts_on: Date.new(2026, 8, 1),
                    ends_on:   Date.new(2026, 10, 31),
                    amount:    200)

      use_case.call(rule: rule)

      expect(rule.transactions.count).to eq(3) # ago, set, out
    end
  end
end
