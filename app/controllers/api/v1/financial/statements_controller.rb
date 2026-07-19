# frozen_string_literal: true

module Api
  module V1
    module Financial
      class StatementsController < Api::BaseController
        def index
          rows = UseCase::Financial::Statements::ListStatementsUseCase.new.call(
            user: @user,
            from: params[:from],
            to:   params[:to]
          )

          render json: ApiResponseSerializer.render_data_array(
            rows,
            serializer:      ::V1::Financial::StatementSummarySerializer,
            serializer_view: :default
          ), status: :ok
        end

        def show
          statement = UseCase::Financial::Statements::ShowMonthlyStatementUseCase.new.call(
            user:  @user,
            month: params[:month]
          )

          render json: ApiResponseSerializer.render(
            statement,
            serializer:      ::V1::Financial::StatementSerializer,
            serializer_view: :default
          ), status: :ok
        end
      end
    end
  end
end
