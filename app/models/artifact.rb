# == Schema Information
#
# Table name: artifacts
#
#  id              :uuid             not null, primary key
#  artifact_type   :string           not null
#  deleted_at      :datetime
#  occurred_at     :datetime
#  processed_data  :jsonb
#  raw_data        :jsonb
#  source          :string
#  status          :string           default("pending")
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null
#  user_id         :uuid             not null
#
# Indexes
#
#  index_artifacts_on_organization_id  (organization_id)
#  index_artifacts_on_status           (status)
#  index_artifacts_on_user_id          (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (user_id => users.id)
#
class Artifact < ApplicationRecord
  belongs_to :organization
  belongs_to :user

  has_one :financial_transaction, class_name: "Financial::Transaction"

  enum status: { pending: "pending", processed: "processed", failed: "failed" }

  validates :artifact_type, presence: true
end
