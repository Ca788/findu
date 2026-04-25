# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::Category::UpdateCategoryUseCase do
  subject(:use_case) { described_class.new }

  let(:user) { create(:user) }
  let!(:category) { create(:financial_category, user: user, name: "Old name") }

  describe "#call" do
    context "when params are valid" do
      it "updates the category attributes" do
        result = use_case.call(user: user, id: category.id, attributes: { name: "New name" })

        expect(result).to eq(category)
        expect(category.reload.name).to eq("New name")
      end

      it "ignores attributes outside the allowed list" do
        original_user_id = category.user_id
        other_user = create(:user)

        use_case.call(
          user: user,
          id: category.id,
          attributes: { name: "Renamed", user_id: other_user.id }
        )

        expect(category.reload.user_id).to eq(original_user_id)
      end
    end

    context "when category does not belong to the user" do
      let(:other_user) { create(:user) }

      it "raises ActiveRecord::RecordNotFound" do
        expect {
          use_case.call(user: other_user, id: category.id, attributes: { name: "Hack" })
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "does not change the category" do
        expect {
          begin
            use_case.call(user: other_user, id: category.id, attributes: { name: "Hack" })
          rescue ActiveRecord::RecordNotFound
            nil
          end
        }.not_to change { category.reload.name }
      end
    end

    context "when category does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          use_case.call(user: user, id: SecureRandom.uuid, attributes: { name: "X" })
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when name is blank" do
      it "raises ActiveRecord::RecordInvalid" do
        expect {
          use_case.call(user: user, id: category.id, attributes: { name: "" })
        }.to raise_error(ActiveRecord::RecordInvalid, /Name/)
      end
    end
  end
end
