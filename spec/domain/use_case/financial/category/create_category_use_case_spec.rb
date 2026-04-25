# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::Category::CreateCategoryUseCase do
  subject(:use_case) { described_class.new }

  let(:user) { create(:user) }
  let(:name) { Faker::Commerce.department(max: 1) }

  describe "#call" do
    context "when params are valid" do
      it "creates a Financial::Category scoped to the user" do
        expect {
          use_case.call(user: user, name: name)
        }.to change(user.categories, :count).by(1)
      end

      it "returns the created category" do
        category = use_case.call(user: user, name: name)

        expect(category).to be_a(Financial::Category)
        expect(category).to be_persisted
        expect(category).to have_attributes(name: name, user_id: user.id)
      end

      it "does not create a category for another user" do
        other_user = create(:user)

        expect {
          use_case.call(user: user, name: name)
        }.not_to change(other_user.categories, :count)
      end
    end

    context "when name is blank" do
      it "raises ActiveRecord::RecordInvalid" do
        expect {
          use_case.call(user: user, name: "")
        }.to raise_error(ActiveRecord::RecordInvalid, /Name/)
      end

      it "does not create a category" do
        expect {
          begin
            use_case.call(user: user, name: "")
          rescue ActiveRecord::RecordInvalid
            nil
          end
        }.not_to change(Financial::Category, :count)
      end
    end
  end
end
