# frozen_string_literal: true

module Api
  module V1
    module Financial
      class ReceiptsController < Api::BaseController
        rescue_from UseCase::Financial::Receipt::GenerateCategoryReceiptUseCase::EmptyPeriodError do |e|
          render json: ApiResponseSerializer.render(
            {},
            success:    false,
            message:    e.message,
            error_code: ErrorMapper.record_not_found.code
          ), status: :not_found
        end

        def index
          receipts = @user.receipts
                          .by_category_id(params[:category_id])
                          .by_payer_phone(params[:payer_phone])
                          .by_status(params[:status])
                          .order(created_at: :desc)
                          .page(page_param)
                          .per(per_page_param)

          render json: ApiResponseSerializer.render_data_array(
            receipts,
            serializer:      ::V1::Financial::ReceiptSerializer,
            serializer_view: serializer_view_param,
            pagination:      pagination_for(receipts)
          ), status: :ok
        end

        def show
          receipt = @user.receipts.find(params[:id])

          render json: ApiResponseSerializer.render(
            receipt,
            serializer:      ::V1::Financial::ReceiptSerializer,
            serializer_view: :extended
          ), status: :ok
        end

        def create
          receipt = UseCase::Financial::Receipt::GenerateCategoryReceiptUseCase.new.call(
            user: @user,
            **generation_params
          )

          enqueue_delivery(receipt) if deliver?

          render json: ApiResponseSerializer.render(
            receipt,
            serializer:      ::V1::Financial::ReceiptSerializer,
            serializer_view: :extended,
            message:         deliver? ? "Receipt generated and queued for delivery." : "Receipt generated."
          ), status: :created
        end

        def deliver
          receipt = @user.receipts.find(params[:id])
          enqueue_delivery(receipt)
          receipt.reload
          return render_delivery_failed(receipt) if receipt.status_failed?

          render json: ApiResponseSerializer.render(
            receipt,
            serializer:      ::V1::Financial::ReceiptSerializer,
            serializer_view: :extended,
            message:         "Receipt queued for delivery."
          ), status: :accepted
        end

        def download
          receipt = @user.receipts.find(params[:id])
          return render_missing_file unless receipt.file.attached?

          send_data receipt.file.download,
                    filename:    receipt.filename,
                    type:        ::Financial::Receipt::CONTENT_TYPE,
                    disposition: "attachment"
        end

        private

        def render_missing_file
          render json: ApiResponseSerializer.render(
            {},
            success:    false,
            message:    "Receipt file is not available.",
            error_code: ErrorMapper.record_not_found.code
          ), status: :not_found
        end

        def render_delivery_failed(receipt)
          render json: ApiResponseSerializer.render(
            receipt,
            serializer:      ::V1::Financial::ReceiptSerializer,
            serializer_view: :extended,
            success:         false,
            message:         receipt.metadata["delivery_error"].presence || "WhatsApp delivery failed.",
            error_code:      ErrorMapper.record_invalid.code
          ), status: :unprocessable_entity
        end

        def receipt_params
          params.require(:receipt).permit(
            :category_id, :from, :to, :transaction_type, :status, :deliver
          )
        end

        def generation_params
          receipt_params.to_h.symbolize_keys.except(:deliver).compact_blank
        end

        def deliver?
          value = receipt_params[:deliver]
          value.nil? || ActiveModel::Type::Boolean.new.cast(value)
        end

        def enqueue_delivery(receipt)
          ::Financial::DeliverReceiptJob.perform_later(receipt)
        rescue RedisClient::Error, ActiveJob::EnqueueError => e
          Rails.logger.error("Receipt enqueue failed, delivering inline: #{e.class}: #{e.message}")
          deliver_inline(receipt)
        end

        def deliver_inline(receipt)
          ::Financial::DeliverReceiptJob.perform_now(receipt)
        rescue StandardError => e
          Rails.logger.error("Inline receipt delivery failed: #{e.class}: #{e.message}")
        end
      end
    end
  end
end
