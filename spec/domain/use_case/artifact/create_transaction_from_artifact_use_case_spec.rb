# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Artifact::CreateTransactionFromArtifactUseCase do
  subject(:use_case) { described_class.new }

  let(:user)     { create(:user) }
  let(:artifact) { create(:artifact, :processed, user: user) }

  describe "#call" do
    context "when artifact has valid processed_data" do
      it "creates a Financial::Transaction scoped to the user" do
        expect {
          use_case.call(artifact: artifact)
        }.to change(user.transactions, :count).by(1)
      end

      it "returns a persisted expense transaction with data from processed_data" do
        transaction = use_case.call(artifact: artifact)

        expect(transaction).to be_a(Financial::Transaction)
        expect(transaction).to be_persisted
        expect(transaction).to have_attributes(
          user_id:          user.id,
          artifact_id:      artifact.id,
          amount:           BigDecimal("150.75"),
          transaction_type: "expense",
          description:      "Supermercado XYZ",
          occurred_at:      artifact.occurred_at
        )
      end
    end

    context "when transaction already exists (idempotency)" do
      before { use_case.call(artifact: artifact) }

      it "does not create a duplicate transaction" do
        expect {
          use_case.call(artifact: artifact.reload)
        }.not_to change(Financial::Transaction, :count)
      end

      it "returns the existing transaction" do
        existing = artifact.reload.financial_transaction

        result = use_case.call(artifact: artifact.reload)

        expect(result.id).to eq(existing.id)
      end
    end

    context "when processed_data is blank" do
      let(:artifact) { create(:artifact, user: user, processed_data: {}) }

      it "raises ArgumentError" do
        expect {
          use_case.call(artifact: artifact)
        }.to raise_error(ArgumentError, /no processed data/)
      end
    end

    context "when amount is missing from processed_data" do
      let(:artifact) do
        create(:artifact, :processed, user: user, processed_data: { "description" => "Mercado" })
      end

      it "raises ArgumentError" do
        expect {
          use_case.call(artifact: artifact)
        }.to raise_error(ArgumentError, /amount is required/)
      end
    end

    context "when description matches an existing category (case-insensitive)" do
      let!(:existing_category) { create(:financial_category, user: user, name: "Supermercado XYZ") }
      let(:artifact) do
        create(:artifact, :processed, user: user,
               processed_data: {
                 "amount"      => "150.75",
                 "description" => "  supermercado xyz  ",
                 "raw_text"    => "x",
                 "confidence"  => 0.95
               })
      end

      it "links the transaction to the existing category" do
        transaction = use_case.call(artifact: artifact)

        expect(transaction.category_id).to eq(existing_category.id)
      end

      it "does not create a new category" do
        expect {
          use_case.call(artifact: artifact)
        }.not_to change(Financial::Category, :count)
      end
    end

    context "when description does not match any existing category" do
      it "creates the transaction without a category and does not auto-create one" do
        expect {
          transaction = use_case.call(artifact: artifact)
          expect(transaction.category_id).to be_nil
        }.not_to change(Financial::Category, :count)
      end
    end

    context "when description matches a category from another user" do
      let(:other_user)        { create(:user) }
      let!(:foreign_category) { create(:financial_category, user: other_user, name: "Supermercado XYZ") }

      it "does not link to the foreign category" do
        transaction = use_case.call(artifact: artifact)

        expect(transaction.category_id).to be_nil
      end
    end
  end
end
