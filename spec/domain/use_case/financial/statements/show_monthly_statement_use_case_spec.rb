# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::Statements::ShowMonthlyStatementUseCase do
  subject(:use_case) { described_class.new }

  let(:user)      { create(:user) }
  let(:other)     { create(:user) }
  let(:month)     { Date.new(2026, 8, 1) }
  let(:groceries) { create(:financial_category, user: user, name: "Groceries") }
  let(:salary)    { create(:financial_category, user: user, name: "Salary") }

  before do
    create(:financial_transaction, :paid,   user: user, category: salary,
           transaction_type: "income",  amount: 3000, competency_month: month)
    create(:financial_transaction, :paid,   user: user, category: groceries,
           transaction_type: "expense", amount: 500,  competency_month: month)
    create(:financial_transaction, :pending, user: user, category: groceries,
           transaction_type: "expense", amount: 300,  competency_month: month)

    create(:financial_transaction, :pending, user: user,
           transaction_type: "expense", amount: 999, competency_month: month.next_month)
    create(:financial_transaction, :paid, user: other,
           transaction_type: "expense", amount: 999, competency_month: month)
  end

  it "aggregates only entries in the requested competency for the given user" do
    statement = use_case.call(user: user, month: "2026-08")

    expect(statement.month).to eq("2026-08")
    expect(statement.forecast[:income]).to eq(3000)
    expect(statement.forecast[:expense]).to eq(800)
    expect(statement.forecast[:balance]).to eq(2200)
    expect(statement.actual[:income_paid]).to eq(3000)
    expect(statement.actual[:expense_paid]).to eq(500)
    expect(statement.actual[:balance]).to eq(2500)
    expect(statement.counts).to eq(pending: 1, paid: 2, total: 3)
  end

  it "defaults to current month when month is not provided" do
    travel_to(Time.zone.local(2026, 8, 15, 12, 0)) do
      statement = use_case.call(user: user)
      expect(statement.month).to eq("2026-08")
    end
  end

  it "includes categories aggregation with forecast and paid" do
    statement = use_case.call(user: user, month: "2026-08")

    groceries_row = statement.by_category.find { |r| r.category_id == groceries.id }
    expect(groceries_row.forecast).to eq(800)
    expect(groceries_row.paid).to eq(500)
  end
end
