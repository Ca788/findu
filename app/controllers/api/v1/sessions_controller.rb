# frozen_string_literal: true

module Api
  module V1
    class SessionsController < Devise::SessionsController
      include ExceptionHandler

      before_action :skip_session_storage
      skip_before_action :verify_signed_out_user, only: :destroy

      def create
        self.resource = warden.authenticate!(auth_options)
        sign_in(resource_name, resource)

        render json: ApiResponseSerializer.render(
          { user: UserSerializer.render_as_hash(resource) },
          message: "Logged in successfully."
        ), status: :ok
      end

      def destroy
        render json: ApiResponseSerializer.render(
          {},
          message: "Logged out successfully."
        ), status: :ok
      end

      private

      def skip_session_storage
        request.session_options[:skip] = true
      end
    end
  end
end
