# frozen_string_literal: true

module Api
  module V1
    class ArtifactsController < Api::BaseController
      def index
        artifacts = @user.artifacts
                         .order(created_at: :desc)
                         .page(page_param)
                         .per(per_page_param)

        render json: ApiResponseSerializer.render_data_array(
          artifacts,
          serializer: ArtifactSerializer,
          serializer_view: :default,
          pagination: pagination_for(artifacts)
        ), status: :ok
      end

      def show
        artifact = @user.artifacts.find(params[:id])

        render json: ApiResponseSerializer.render(
          artifact,
          serializer: ArtifactSerializer,
          serializer_view: :extended
        ), status: :ok
      end

      def create
        artifact = UseCase::Artifact::CreateArtifactUseCase.new.call(
          user: @user,
          file: artifact_params[:file],
          artifact_type: artifact_params[:artifact_type],
          source: artifact_params[:source]
        )

        render json: ApiResponseSerializer.render(
          artifact,
          serializer: ArtifactSerializer,
          serializer_view: :extended,
          message: "Artifact uploaded; OCR processing queued."
        ), status: :accepted
      end

      private

      def artifact_params
        params.permit(:file, :artifact_type, :source)
      end
    end
  end
end
