# == Schema Information
#
# Table name: insights
#
#  id             :uuid             not null, primary key
#  content        :text
#  metadata       :jsonb
#  reference_type :string           not null
#  severity       :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  reference_id   :uuid
#  user_id        :uuid             not null
#
# Indexes
#
#  index_insights_on_reference_type  (reference_type)
#  index_insights_on_user_id         (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
module Intelligence
  class Insight < ApplicationRecord
    REFERENCE_MONTHLY_STATEMENT = "monthly_statement"

    SEVERITIES      = %w[info warning critical].freeze
    DEFAULT_SEVERITY = "info"

    belongs_to :user

    validates :reference_type, presence: true
    validates :severity, inclusion: { in: SEVERITIES }, allow_nil: true

    scope :by_reference_type, ->(type)     { where(reference_type: type) if type.present? }
    scope :by_severity,       ->(severity) { where(severity: severity) if severity.present? }
    scope :for_period,        ->(period)   { where("metadata->>'period' = ?", period) if period.present? }
  end
end
