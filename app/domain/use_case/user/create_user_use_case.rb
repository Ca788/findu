# frozen_string_literal: true

class UseCase::User::CreateUserUseCase
  Result = Struct.new(:user, :token, keyword_init: true)

  # @param [String] name
  # @param [String] email
  # @param [String] password
  # @param [String] password_confirmation
  # @param [String] phone
  # @return [Result]
  def call(name:, email:, password:, password_confirmation:, phone: nil)
    user = User.create!(
      name: name,
      email: email,
      password: password,
      password_confirmation: password_confirmation,
      phone: phone
    )

    token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first

    Result.new(user: user, token: token)
  rescue ActiveRecord::RecordInvalid => e
    raise StandardError, e.record.errors.full_messages.join(", ")
  rescue ActiveRecord::RecordNotUnique
    raise StandardError, "A user with this email already exists."
  end
end
