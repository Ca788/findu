# frozen_string_literal: true

class UseCase::User::ResetPasswordUseCase
  # @param [String] reset_password_token
  # @param [String] password
  # @param [String] password_confirmation
  # @return [User]
  def call(reset_password_token:, password:, password_confirmation:)
    user = User.reset_password_by_token(
      reset_password_token: reset_password_token,
      password: password,
      password_confirmation: password_confirmation
    )

    if user.errors.any?
      raise ActiveRecord::RecordInvalid, user
    end

    user
  end
end
