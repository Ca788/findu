# frozen_string_literal: true

module Api
  module V1
    class OrganizationController < Api::BaseController
      skip_before_action :authenticate_user!, only: [:create]
      skip_before_action :set_user, only: [:create]
      skip_before_action :set_organization, only: [:create]

      def show
        render json: ApiResponseSerializer.render(
          { organization: OrganizationSerializer.render_as_hash(@organization) }
        ), status: :ok
      end

      def create
        organization = UseCase::Organization::CreateOrganizationUseCase.new.call(
          name: organization_params[:name],
          plan: organization_params[:plan]
        )

        render json: ApiResponseSerializer.render(
          { organization: OrganizationSerializer.render_as_hash(organization) },
          message: "Organization created successfully."
        ), status: :created
      end

      private

      def organization_params
        params.require(:organization).permit(:name, :plan)
      end
    end
  end
end
