# frozen_string_literal: true

module Api
  module V1
    class UserController < Api::BaseController
      skip_before_action :authenticate_user!, only: [:create]
      skip_before_action :set_user, only: [:create]
      skip_before_action :set_organization, only: [:create]

      def show
        render json: ApiResponseSerializer.render(
          { user: UserSerializer.render_as_hash(@user) }
        ), status: :ok
      end

      def create
        result = UseCase::User::CreateUserUseCase.new.call(**user_params.to_h.symbolize_keys)

        response.set_header("Authorization", "Bearer #{result.token}")

        render json: ApiResponseSerializer.render(
          { user: UserSerializer.render_as_hash(result.user) },
          message: "User created successfully."
        ), status: :created
      end

      private

      def user_params
        params.require(:user).permit(:organization_id, :name, :email, :phone, :role, :password, :password_confirmation)
      end
    end
  end
end
