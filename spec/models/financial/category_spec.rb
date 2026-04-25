# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Financial::Category do
  let(:user) { create(:user) }

  describe 'validations' do
    context 'when name is blank' do
      it 'is invalid' do
        category = build(:financial_category, user: user, name: '')

        expect(category).not_to be_valid
        expect(category.errors[:name]).to include("can't be blank")
      end
    end

    context 'when name is present' do
      it 'is valid' do
        category = build(:financial_category, user: user)

        expect(category).to be_valid
      end
    end
  end

  describe 'associations' do
    it 'belongs to a user' do
      category = create(:financial_category, user: user)

      expect(category.user).to eq(user)
    end
  end
end
