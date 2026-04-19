# frozen_string_literal: true

module Api
  module V1
    class SessionsController < Devise::SessionsController
      include ExceptionHandler

      before_action :skip_session_storage

      respond_to :json

      def create
        self.resource = warden.authenticate!(auth_options)
        sign_in(resource_name, resource)

        data = {
          user: UserSerializer.render_as_hash(resource)
        }

        render json: ApiResponseSerializer.render(
          data,
          message: "Logged in successfully."
        ), status: :ok
      end

      private

      def skip_session_storage
        request.session_options[:skip] = true
      end

      def respond_to_on_destroy
        if current_user
          render json: ApiResponseSerializer.render(
            {},
            message: "Logged out successfully."
          ), status: :ok
        else
          render json: ApiResponseSerializer.render(
            {},
            success: false,
            message: "Logout failed."
          ), status: :unauthorized
        end
      end
    end
  end
end
