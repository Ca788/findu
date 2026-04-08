# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UseCase::Organization::CreateOrganizationUseCase do
  subject(:use_case) { described_class.new }

  let(:name) { Faker::Company.name }
  let(:plan) { 'premium' }

  describe '#call' do
    context 'when all parameters are valid' do
      it 'creates an Organization' do
        expect {
          use_case.call(name: name, plan: plan)
        }.to change(Organization, :count).by(1)
      end

      it 'returns the persisted organization with correct attributes' do
        organization = use_case.call(name: name, plan: plan)

        expect(organization).to be_a(Organization)
        expect(organization).to be_persisted
        expect(organization).to have_attributes(name: name, plan: plan)
      end
    end

    context 'when plan is not provided' do
      it 'creates an organization with nil plan' do
        organization = use_case.call(name: name)

        expect(organization).to be_persisted
        expect(organization.plan).to be_nil
      end
    end

    context 'when name is blank' do
      it 'raises an error' do
        expect {
          use_case.call(name: '', plan: plan)
        }.to raise_error(StandardError, /Name/)
      end
    end

    context 'when name is nil' do
      it 'raises an error' do
        expect {
          use_case.call(name: nil, plan: plan)
        }.to raise_error(StandardError)
      end
    end

    context 'when name already exists' do
      let!(:existing_organization) { create(:organization, name: name) }

      it 'still creates a new organization (no uniqueness constraint)' do
        expect {
          use_case.call(name: name, plan: plan)
        }.to change(Organization, :count).by(1)
      end
    end
  end
end
