# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::Transaction::CreateTransactionUseCase do
  subject(:use_case) { described_class.new }

  let(:user)     { create(:user) }
  let(:category) { create(:financial_category, user: user) }

  describe "#call" do
    context "when params are valid" do
      it "creates a Financial::Transaction scoped to the user" do
        expect {
          use_case.call(user: user, amount: 150.75, transaction_type: "expense")
        }.to change(user.transactions, :count).by(1)
      end

      it "returns a persisted transaction with the given attributes" do
        transaction = use_case.call(
          user: user,
          amount: 150.75,
          transaction_type: "expense",
          description: "Lunch",
          occurred_at: Time.current,
          category_id: category.id,
          metadata: { source: "manual" }
        )

        expect(transaction).to be_a(Financial::Transaction)
        expect(transaction).to be_persisted
        expect(transaction).to have_attributes(
          user_id:          user.id,
          amount:           150.75,
          transaction_type: "expense",
          description:      "Lunch",
          category_id:      category.id
        )
      end
    end

    context "when amount is missing" do
      it "raises ActiveRecord::RecordInvalid" do
        expect {
          use_case.call(user: user, amount: nil, transaction_type: "expense")
        }.to raise_error(ActiveRecord::RecordInvalid, /Amount/)
      end
    end

    context "when amount is not positive" do
      it "raises ActiveRecord::RecordInvalid" do
        expect {
          use_case.call(user: user, amount: 0, transaction_type: "expense")
        }.to raise_error(ActiveRecord::RecordInvalid, /Amount/)
      end
    end

    context "when transaction_type is invalid" do
      it "raises ArgumentError" do
        expect {
          use_case.call(user: user, amount: 100, transaction_type: "invalid")
        }.to raise_error(ArgumentError)
      end
    end

    context "when category belongs to another user" do
      let(:other_user)      { create(:user) }
      let(:foreign_category) { create(:financial_category, user: other_user) }

      it "raises ActiveRecord::RecordNotFound" do
        expect {
          use_case.call(user: user, amount: 100, transaction_type: "expense", category_id: foreign_category.id)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "does not create the transaction" do
        expect {
          begin
            use_case.call(user: user, amount: 100, transaction_type: "expense", category_id: foreign_category.id)
          rescue ActiveRecord::RecordNotFound
            nil
          end
        }.not_to change(Financial::Transaction, :count)
      end
    end

    context "when category is omitted" do
      it "creates the transaction without category" do
        transaction = use_case.call(user: user, amount: 50, transaction_type: "income")

        expect(transaction.category_id).to be_nil
      end
    end

    context "when category_name is given" do
      it "creates the category on the fly and links it" do
        expect {
          use_case.call(user: user, amount: 80, transaction_type: "expense", category_name: "Pets")
        }.to change(user.categories, :count).by(1)

        expect(user.transactions.last.category.name).to eq("Pets")
      end

      it "reuses an existing category regardless of casing" do
        create(:financial_category, user: user, name: "Pets")

        expect {
          use_case.call(user: user, amount: 80, transaction_type: "expense", category_name: "pets")
        }.not_to change(user.categories, :count)

        expect(user.transactions.last.category.name).to eq("Pets")
      end

      it "gives precedence to category_id over category_name" do
        transaction = use_case.call(
          user:             user,
          amount:           80,
          transaction_type: "expense",
          category_id:      category.id,
          category_name:    "Pets"
        )

        expect(transaction.category_id).to eq(category.id)
        expect(user.categories.where(name: "Pets")).to be_empty
      end
    end

    context "when payer data is given" do
      it "stores the payer identification" do
        transaction = use_case.call(
          user:             user,
          amount:           120,
          transaction_type: "income",
          payer_name:       "Maria",
          payer_phone:      "+5511988887777"
        )

        expect(transaction).to have_attributes(payer_name: "Maria", payer_phone: "+5511988887777")
      end
    end

    context "budget warnings" do
      it "returns an empty array when there is no covering budget" do
        transaction = use_case.call(user: user, amount: 100, transaction_type: "expense", occurred_at: Time.current)

        expect(transaction.budget_warnings).to eq([])
      end

      it "returns an empty array for income even when budget is exceeded" do
        create(:financial_budget, user: user, limit_amount: 100)
        create(:financial_transaction, user: user, amount: 200, transaction_type: "expense", occurred_at: Date.current)

        transaction = use_case.call(user: user, amount: 500, transaction_type: "income", occurred_at: Time.current)

        expect(transaction.budget_warnings).to eq([])
      end

      it "returns a warning when the new expense pushes usage above 80%" do
        create(:financial_budget, user: user, limit_amount: 1000)

        transaction = use_case.call(user: user, amount: 900, transaction_type: "expense", occurred_at: Time.current)

        expect(transaction.budget_warnings.size).to eq(1)
        expect(transaction.budget_warnings.first).to include(status: "warning", usage_percent: 90.0)
      end

      it "marks the warning as 'exceeded' when usage goes above 100%" do
        create(:financial_budget, user: user, limit_amount: 1000)

        transaction = use_case.call(user: user, amount: 1500, transaction_type: "expense", occurred_at: Time.current)

        expect(transaction.budget_warnings.first).to include(status: "exceeded")
      end

      it "still persists the transaction even when the budget is exceeded (non-blocking)" do
        create(:financial_budget, user: user, limit_amount: 100)

        expect {
          use_case.call(user: user, amount: 5000, transaction_type: "expense", occurred_at: Time.current)
        }.to change(Financial::Transaction, :count).by(1)
      end
    end
  end
end
