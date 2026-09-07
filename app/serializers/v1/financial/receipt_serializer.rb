# frozen_string_literal: true

module V1
  module Financial
    class ReceiptSerializer < Blueprinter::Base
      identifier :id

      view :default do
        fields :category_id, :payer_name, :payer_phone, :period_start, :period_end,
               :total_amount, :status, :sent_at

        field(:filename) { |receipt| receipt.filename }
        field(:file_attached) { |receipt| receipt.file.attached? }
      end

      view :extended do
        include_view :default
        fields :metadata, :created_at, :updated_at
      end
    end
  end
end
