# frozen_string_literal: true

module Api
  module V1
    module Intelligence
      class InsightsController < Api::BaseController
        def index
          insights = @user.insights
                          .by_reference_type(params[:reference_type])
                          .by_severity(params[:severity])
                          .for_period(params[:period])
                          .order(created_at: :desc)
                          .page(page_param)
                          .per(per_page_param)

          render json: ApiResponseSerializer.render_data_array(
            insights,
            serializer:      ::V1::Intelligence::InsightSerializer,
            serializer_view: serializer_view_param,
            pagination:      pagination_for(insights)
          ), status: :ok
        end
      end
    end
  end
end
