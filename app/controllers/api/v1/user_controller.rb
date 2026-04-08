# frozen_string_literal: true

module Api
  module V1
    class UserController < Api::BaseController
      def show
        data = {
          user: UserSerializer.render_as_hash(@user)
        }

        render json: ApiResponseSerializer.render(data), status: :ok
      end
    end
  end
end
