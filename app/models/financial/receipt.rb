# frozen_string_literal: true

module Financial
  class Receipt < ApplicationRecord
    STATUSES = { pending: "pending", sent: "sent", failed: "failed" }.freeze

    CONTENT_TYPE    = "application/pdf"
    FILENAME_PREFIX = "comprovante"

    belongs_to :user

    has_one_attached :file, dependent: :purge_later

    enum status: STATUSES, _prefix: :status

    validates :payer_phone, :period_start, :period_end, presence: true

    scope :by_payer_phone, ->(phone)  { where(payer_phone: phone) if phone.present? }
    scope :by_status,      ->(status) { where(status: status) if status.present? }

    # @return [String]
    def filename
      "#{FILENAME_PREFIX}-#{period_start.strftime('%Y%m')}-#{period_end.strftime('%Y%m')}.pdf"
    end
  end
end
