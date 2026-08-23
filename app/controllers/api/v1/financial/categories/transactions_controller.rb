# frozen_string_literal: true

module Api
  module V1
    module Financial
      module Categories
        class TransactionsController < Api::BaseController
          def index
            transactions = UseCase::Financial::Transaction::ListTransactionsByCategoryUseCase.new.call(
              user:        @user,
              category_id: params[:category_id],
              **filters
            ).page(page_param).per(per_page_param)

            render json: ApiResponseSerializer.render_data_array(
              transactions,
              serializer:      ::V1::Financial::TransactionSerializer,
              serializer_view: serializer_view_param,
              pagination:      pagination_for(transactions)
            ), status: :ok
          end

          private

          def filters
            {
              from:             params[:from],
              to:               params[:to],
              transaction_type: params[:transaction_type],
              status:           params[:status],
              payer_phone:      params[:payer_phone]
            }
          end
        end
      end
    end
  end
end
