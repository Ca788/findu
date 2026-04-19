# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UseCase::User::ResetPasswordUseCase do
  subject(:use_case) { described_class.new }

  let(:user) { create(:user) }
  let(:new_password) { 'newpassword123' }
  let(:raw_token) { user.send_reset_password_instructions }

  describe '#call' do
    context 'when token and passwords are valid' do
      it 'returns the user' do
        result = use_case.call(
          reset_password_token: raw_token,
          password: new_password,
          password_confirmation: new_password
        )

        expect(result).to be_a(User)
        expect(result.id).to eq(user.id)
      end

      it 'updates the user password' do
        use_case.call(
          reset_password_token: raw_token,
          password: new_password,
          password_confirmation: new_password
        )

        expect(user.reload.valid_password?(new_password)).to be true
      end

      it 'clears the reset_password_token' do
        use_case.call(
          reset_password_token: raw_token,
          password: new_password,
          password_confirmation: new_password
        )

        expect(user.reload.reset_password_token).to be_nil
      end
    end

    context 'when token is invalid' do
      it 'raises ActiveRecord::RecordInvalid' do
        expect {
          use_case.call(
            reset_password_token: 'invalid-token',
            password: new_password,
            password_confirmation: new_password
          )
        }.to raise_error(ActiveRecord::RecordInvalid, /Reset password token/)
      end

      it 'does not change the password' do
        original_encrypted = user.encrypted_password

        begin
          use_case.call(
            reset_password_token: 'invalid-token',
            password: new_password,
            password_confirmation: new_password
          )
        rescue ActiveRecord::RecordInvalid
          # expected
        end

        expect(user.reload.encrypted_password).to eq(original_encrypted)
      end
    end

    context 'when password confirmation does not match' do
      it 'raises ActiveRecord::RecordInvalid' do
        expect {
          use_case.call(
            reset_password_token: raw_token,
            password: new_password,
            password_confirmation: 'different'
          )
        }.to raise_error(ActiveRecord::RecordInvalid, /Password/)
      end
    end

    context 'when password is too short' do
      it 'raises ActiveRecord::RecordInvalid' do
        expect {
          use_case.call(
            reset_password_token: raw_token,
            password: '123',
            password_confirmation: '123'
          )
        }.to raise_error(ActiveRecord::RecordInvalid, /Password/)
      end
    end
  end
end
