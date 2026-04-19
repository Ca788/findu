# frozen_string_literal: true

module Api
  module V1
    class PasswordsController < Api::BaseController
      skip_before_action :authenticate_user!, only: [:create, :update]
      skip_before_action :set_user, only: [:create, :update]

      def create
        user = User.find_by(email: forgot_params[:email].to_s.downcase.strip)
        user&.send_reset_password_instructions

        render json: ApiResponseSerializer.render(
          {},
          message: "If the email exists, password reset instructions were sent."
        ), status: :ok
      end

      def update
        UseCase::User::ResetPasswordUseCase.new.call(
          reset_password_token: reset_params[:reset_password_token],
          password: reset_params[:password],
          password_confirmation: reset_params[:password_confirmation]
        )

        render json: ApiResponseSerializer.render(
          {},
          message: "Password reset successfully."
        ), status: :ok
      end

      private

      def forgot_params
        params.require(:user).permit(:email)
      end

      def reset_params
        params.require(:user).permit(:reset_password_token, :password, :password_confirmation)
      end
    end
  end
end
