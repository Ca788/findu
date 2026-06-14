# frozen_string_literal: true

module Api
  module V1
    module Financial
      class TransactionsController < Api::BaseController
        def index
          transactions = @user.transactions
                              .by_type(params[:transaction_type])
                              .by_category(params[:category_id])
                              .occurred_from(params[:from])
                              .occurred_until(params[:to])
                              .order(occurred_at: :desc, created_at: :desc)
                              .page(page_param)
                              .per(per_page_param)

          render json: ApiResponseSerializer.render_data_array(
            transactions,
            serializer: ::V1::Financial::TransactionSerializer,
            serializer_view: :default,
            pagination: pagination_for(transactions)
          ), status: :ok
        end

        def show
          transaction = @user.transactions.find(params[:id])

          render json: ApiResponseSerializer.render(
            transaction,
            serializer: ::V1::Financial::TransactionSerializer,
            serializer_view: :extended
          ), status: :ok
        end

        def create
          transaction = UseCase::Financial::Transaction::CreateTransactionUseCase.new.call(
            user: @user,
            **transaction_params.to_h.symbolize_keys
          )

          render json: ApiResponseSerializer.render(
            transaction,
            serializer: ::V1::Financial::TransactionSerializer,
            serializer_view: :extended,
            message: "Transaction created successfully."
          ), status: :created
        end

        def update
          transaction = UseCase::Financial::Transaction::UpdateTransactionUseCase.new.call(
            user: @user,
            id: params[:id],
            **transaction_params.to_h.symbolize_keys
          )

          render json: ApiResponseSerializer.render(
            transaction,
            serializer: ::V1::Financial::TransactionSerializer,
            serializer_view: :extended,
            message: "Transaction updated successfully."
          ), status: :ok
        end

        def destroy
          UseCase::Financial::Transaction::DestroyTransactionUseCase.new.call(
            user: @user,
            id:   params[:id]
          )

          render json: ApiResponseSerializer.render(
            {},
            message: "Transaction deleted successfully."
          ), status: :ok
        end

        def batch_destroy
          result = UseCase::Financial::Transaction::DestroyTransactionsBatchUseCase.new.call(
            user: @user,
            ids:  batch_destroy_ids
          )

          render json: ApiResponseSerializer.render(
            {},
            message: "#{result.destroyed_ids.size} transaction(s) deleted.",
            metadata: {
              destroyed_ids: result.destroyed_ids,
              missing_ids:   result.missing_ids
            }
          ), status: :ok
        end

        private

        def transaction_params
          params.require(:transaction).permit(
            *(::Financial::Transaction::PERMITTED_ATTRIBUTES - [:metadata]),
            metadata: {}
          )
        end

        def batch_destroy_ids
          raw = params[:ids].presence || params.dig(:transaction, :ids)
          Array(raw)
        end
      end
    end
  end
end
