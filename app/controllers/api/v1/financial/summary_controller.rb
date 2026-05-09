# frozen_string_literal: true

module Api
  module V1
    module Financial
      class SummaryController < Api::BaseController
        def show
          result = UseCase::Financial::SummaryUseCase.new.call(
            user:             @user,
            from:             params[:from],
            to:               params[:to],
            transaction_type: params[:transaction_type],
            category_id:      params[:category_id]
          )

          render json: ApiResponseSerializer.render(
            result,
            serializer: ::V1::Financial::SummarySerializer,
            metadata: { from: result.from, to: result.to }
          ), status: :ok
        end
      end
    end
  end
end
