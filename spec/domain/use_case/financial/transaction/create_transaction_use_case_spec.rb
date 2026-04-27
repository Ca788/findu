# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::Transaction::CreateTransactionUseCase do
  subject(:use_case) { described_class.new }

  let(:user) { create(:user) }
  let(:category) { create(:financial_category, user: user) }

  let(:valid_attributes) do
    {
      amount: 150.75,
      transaction_type: "expense",
      description: "Lunch",
      occurred_at: Time.current,
      category_id: category.id,
      metadata: { source: "manual" }
    }
  end

  describe "#call" do
    context "when params are valid" do
      it "creates a Financial::Transaction scoped to the user" do
        expect {
          use_case.call(user: user, attributes: valid_attributes)
        }.to change(user.transactions, :count).by(1)
      end

      it "returns the persisted transaction with the given attributes" do
        transaction = use_case.call(user: user, attributes: valid_attributes)

        expect(transaction).to be_a(Financial::Transaction)
        expect(transaction).to be_persisted
        expect(transaction).to have_attributes(
          user_id: user.id,
          amount: 150.75,
          transaction_type: "expense",
          description: "Lunch",
          category_id: category.id
        )
      end

      it "ignores attributes outside the allowed list" do
        other_user = create(:user)

        transaction = use_case.call(
          user: user,
          attributes: valid_attributes.merge(user_id: other_user.id, id: SecureRandom.uuid)
        )

        expect(transaction.user_id).to eq(user.id)
      end
    end

    context "when amount is missing" do
      it "raises ActiveRecord::RecordInvalid" do
        expect {
          use_case.call(user: user, attributes: valid_attributes.except(:amount))
        }.to raise_error(ActiveRecord::RecordInvalid, /Amount/)
      end
    end

    context "when amount is not positive" do
      it "raises ActiveRecord::RecordInvalid" do
        expect {
          use_case.call(user: user, attributes: valid_attributes.merge(amount: 0))
        }.to raise_error(ActiveRecord::RecordInvalid, /Amount/)
      end
    end

    context "when transaction_type is invalid" do
      it "raises ArgumentError (enum rejection)" do
        expect {
          use_case.call(user: user, attributes: valid_attributes.merge(transaction_type: "invalid"))
        }.to raise_error(ArgumentError)
      end
    end

    context "when category belongs to another user" do
      let(:other_user) { create(:user) }
      let(:foreign_category) { create(:financial_category, user: other_user) }

      it "raises ActiveRecord::RecordInvalid" do
        expect {
          use_case.call(user: user, attributes: valid_attributes.merge(category_id: foreign_category.id))
        }.to raise_error(ActiveRecord::RecordInvalid, /must belong to the user/)
      end

      it "does not create the transaction" do
        expect {
          begin
            use_case.call(user: user, attributes: valid_attributes.merge(category_id: foreign_category.id))
          rescue ActiveRecord::RecordInvalid
            nil
          end
        }.not_to change(Financial::Transaction, :count)
      end
    end

    context "when category is omitted" do
      it "creates the transaction without category" do
        transaction = use_case.call(user: user, attributes: valid_attributes.except(:category_id))

        expect(transaction.category_id).to be_nil
      end
    end
  end
end
