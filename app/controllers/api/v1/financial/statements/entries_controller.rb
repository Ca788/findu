# frozen_string_literal: true

module Api
  module V1
    module Financial
      module Statements
        class EntriesController < Api::BaseController
          def create
            transaction = UseCase::Financial::Transaction::CreateTransactionUseCase.new.call(
              user: @user,
              **entry_params.to_h.symbolize_keys.merge(
                competency_month: competency_from_params
              )
            )

            render json: ApiResponseSerializer.render(
              transaction,
              serializer:      ::V1::Financial::TransactionSerializer,
              serializer_view: :extended,
              message:         "Entry added to statement."
            ), status: :created
          end

          def update
            transaction = UseCase::Financial::Transaction::UpdateTransactionUseCase.new.call(
              user: @user,
              id:   params[:id],
              **entry_params.to_h.symbolize_keys
            )

            render json: ApiResponseSerializer.render(
              transaction,
              serializer:      ::V1::Financial::TransactionSerializer,
              serializer_view: :extended,
              message:         "Entry updated."
            ), status: :ok
          end

          def destroy
            UseCase::Financial::Transaction::DestroyTransactionUseCase.new.call(
              user: @user,
              id:   params[:id]
            )

            render json: ApiResponseSerializer.render({}, message: "Entry deleted."), status: :ok
          end

          def mark_paid
            transaction = UseCase::Financial::Statements::MarkPaidUseCase.new.call(
              user:    @user,
              id:      params[:id],
              paid_at: params[:paid_at]
            )

            render json: ApiResponseSerializer.render(
              transaction,
              serializer:      ::V1::Financial::TransactionSerializer,
              serializer_view: :extended,
              message:         "Entry marked as paid."
            ), status: :ok
          end

          def mark_pending
            transaction = UseCase::Financial::Statements::MarkPendingUseCase.new.call(
              user: @user,
              id:   params[:id]
            )

            render json: ApiResponseSerializer.render(
              transaction,
              serializer:      ::V1::Financial::TransactionSerializer,
              serializer_view: :extended,
              message:         "Entry marked as pending."
            ), status: :ok
          end

          private

          def entry_params
            params.require(:entry).permit(
              *(::Financial::Transaction::PERMITTED_ATTRIBUTES - [:metadata]),
              metadata: {}
            )
          end

          # Uses "YYYY-MM" from the URL (:statement_month) or competency in the payload.
          def competency_from_params
            entry_params[:competency_month] || params[:statement_month]
          end
        end
      end
    end
  end
end
