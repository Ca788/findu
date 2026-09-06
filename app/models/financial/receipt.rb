# frozen_string_literal: true

# == Schema Information
#
# Table name: receipts
#
#  id           :uuid             not null, primary key
#  metadata     :jsonb
#  payer_name   :string
#  payer_phone  :string           not null
#  period_end   :date             not null
#  period_start :date             not null
#  sent_at      :datetime
#  status       :string           default("pending"), not null
#  total_amount :decimal(10, 2)   default(0.0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  category_id  :uuid
#  user_id      :uuid             not null
#
# Indexes
#
#  index_receipts_on_category_id             (category_id)
#  index_receipts_on_status                  (status)
#  index_receipts_on_user_id                 (user_id)
#  index_receipts_on_user_id_and_created_at  (user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#  fk_rails_...  (user_id => users.id)
#
module Financial
  class Receipt < ApplicationRecord
    STATUSES = { pending: "pending", sent: "sent", failed: "failed" }.freeze

    CONTENT_TYPE    = "application/pdf"
    FILENAME_PREFIX = "comprovante"

    belongs_to :user
    belongs_to :category, class_name: "Financial::Category", optional: true

    has_one_attached :file, dependent: :purge_later

    enum status: STATUSES, _prefix: :status

    validates :payer_phone, :period_start, :period_end, presence: true

    scope :by_payer_phone, ->(phone)       { where(payer_phone: phone) if phone.present? }
    scope :by_category_id, ->(category_id) { where(category_id: category_id) if category_id.present? }
    scope :by_status,      ->(status)      { where(status: status) if status.present? }

    # @return [String]
    def filename
      "#{FILENAME_PREFIX}-#{period_start.strftime('%Y%m')}-#{period_end.strftime('%Y%m')}.pdf"
    end
  end
end
