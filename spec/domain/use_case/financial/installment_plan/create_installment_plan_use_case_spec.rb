# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::InstallmentPlan::CreateInstallmentPlanUseCase do
  subject(:use_case) { described_class.new }

  let(:user) { create(:user) }

  it "creates the plan and materializes N pending transactions across consecutive months" do
    plan = use_case.call(
      user: user,
      attributes: {
        description:        "Celular",
        transaction_type:   "expense",
        monthly_amount:     500,
        total_installments: 5,
        first_competency:   Date.new(2026, 8, 1)
      }
    )

    expect(plan).to be_persisted
    expect(plan.transactions.count).to eq(5)
    expect(plan.transactions.pluck(:competency_month)).to eq([
      Date.new(2026, 8, 1),
      Date.new(2026, 9, 1),
      Date.new(2026, 10, 1),
      Date.new(2026, 11, 1),
      Date.new(2026, 12, 1)
    ])
    expect(plan.transactions.pluck(:installment_number)).to eq([1, 2, 3, 4, 5])
    expect(plan.transactions.pluck(:description)).to all(match(%r{Celular \d/5}))
    expect(plan.transactions.pluck(:status).uniq).to eq(["pending"])
    expect(plan.remaining_count).to eq(5)
    expect(plan.remaining_amount).to eq(2500)
    expect(plan.end_competency).to eq(Date.new(2026, 12, 1))
  end
end
