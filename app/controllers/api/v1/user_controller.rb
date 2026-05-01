# frozen_string_literal: true

module Api
  module V1
    class UserController < Api::BaseController
      include ExceptionHandler

      skip_before_action :authenticate_user!, only: [:create]
      skip_before_action :set_user, only: [:create]

      def show
        render json: ApiResponseSerializer.render(
          { user: ::V1::UserSerializer.render_as_hash(@user) }
        ), status: :ok
      end

      def create
        result = UseCase::User::CreateUserUseCase.new.call(
          name: user_params[:name],
          email: user_params[:email],
          password: user_params[:password],
          password_confirmation: user_params[:password_confirmation],
          phone: user_params[:phone]
        )

        response.set_header("Authorization", "Bearer #{result.token}")

        render json: ApiResponseSerializer.render(
          { user: ::V1::UserSerializer.render_as_hash(result.user) },
          message: "User created successfully."
        ), status: :created
      end

      private

      def user_params
        params.require(:user).permit(:name, :email, :phone, :password, :password_confirmation)
      end
    end
  end
end
