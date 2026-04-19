# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UseCase::User::CreateUserUseCase do
  subject(:use_case) { described_class.new }

  let(:name) { Faker::Name.name }
  let(:email) { Faker::Internet.email }
  let(:password) { 'password123' }
  let(:phone) { Faker::PhoneNumber.cell_phone }

  describe '#call' do
    context 'when all parameters are valid' do
      it 'creates a User' do
        expect {
          use_case.call(name: name, email: email, password: password, password_confirmation: password)
        }.to change(User, :count).by(1)
      end

      it 'returns a Result with user and token' do
        result = use_case.call(name: name, email: email, password: password, password_confirmation: password)

        expect(result.user).to be_a(User)
        expect(result.user).to be_persisted
        expect(result.user).to have_attributes(name: name, email: email)
        expect(result.token).to be_present
      end

      it 'returns a valid JWT token containing the user id' do
        result = use_case.call(name: name, email: email, password: password, password_confirmation: password)

        decoded = JWT.decode(result.token, Rails.application.secret_key_base, true, algorithm: 'HS256')
        expect(decoded.first['sub']).to eq(result.user.id)
      end
    end

    context 'when phone is provided' do
      it 'creates user with phone' do
        result = use_case.call(
          name: name, email: email, password: password, password_confirmation: password, phone: phone
        )

        expect(result.user).to have_attributes(phone: phone)
      end
    end

    context 'when email already exists' do
      let!(:existing_user) { create(:user, email: email) }

      it 'raises an error' do
        expect {
          use_case.call(name: name, email: email, password: password, password_confirmation: password)
        }.to raise_error(StandardError, /Email/)
      end

      it 'does not create a new user' do
        expect {
          use_case.call(
            name: name, email: email, password: password, password_confirmation: password
          ) rescue nil
        }.not_to change(User, :count)
      end
    end

    context 'when password confirmation does not match' do
      it 'raises a validation error' do
        expect {
          use_case.call(name: name, email: email, password: password, password_confirmation: 'wrong')
        }.to raise_error(StandardError, /Password/)
      end
    end

    context 'when name is blank' do
      it 'raises a validation error' do
        expect {
          use_case.call(name: '', email: email, password: password, password_confirmation: password)
        }.to raise_error(StandardError, /Name/)
      end
    end

    context 'when email is blank' do
      it 'raises a validation error' do
        expect {
          use_case.call(name: name, email: '', password: password, password_confirmation: password)
        }.to raise_error(StandardError, /Email/)
      end
    end
  end
end
