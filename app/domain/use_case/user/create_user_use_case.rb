# frozen_string_literal: true

class UseCase::User::CreateUserUseCase
  Result = Struct.new(:user, :token, keyword_init: true)

  # @param [String] organization_id
  # @param [String] name
  # @param [String] email
  # @param [String] password
  # @param [String] password_confirmation
  # @param [String] phone
  # @param [String] role
  # @return [Result]
  def call(organization_id:, name:, email:, password:, password_confirmation:, phone: nil, role: nil)
    organization = Organization.find(organization_id)

    user = organization.users.create!(
      name: name,
      email: email,
      password: password,
      password_confirmation: password_confirmation,
      phone: phone,
      role: role
    )

    token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first

    Result.new(user: user, token: token)
  end
end
