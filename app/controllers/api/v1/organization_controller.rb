# frozen_string_literal: true

module Api
  module V1
    class OrganizationController < Api::BaseController
      def show
        data = {
          organization: OrganizationSerializer.render_as_hash(@organization)
        }

        render json: ApiResponseSerializer.render(data), status: :ok
      end
    end
  end
end
