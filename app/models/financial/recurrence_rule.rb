# == Schema Information
#
# Table name: recurrence_rules
#
#  id               :uuid             not null, primary key
#  active           :boolean          default(TRUE), not null
#  amount           :decimal(10, 2)   not null
#  canceled_at      :datetime
#  day_of_month     :integer
#  description      :string
#  ends_on          :date
#  frequency        :string           default("monthly"), not null
#  starts_on        :date             not null
#  transaction_type :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  category_id      :uuid
#  user_id          :uuid             not null
#
# Indexes
#
#  index_recurrence_rules_on_category_id         (category_id)
#  index_recurrence_rules_on_user_id             (user_id)
#  index_recurrence_rules_on_user_id_and_active  (user_id,active)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#  fk_rails_...  (user_id => users.id)
#
module Financial
  class RecurrenceRule < ApplicationRecord
    FREQUENCIES = { monthly: "monthly" }.freeze

    PERMITTED_ATTRIBUTES = %i[
      transaction_type
      amount
      description
      frequency
      day_of_month
      starts_on
      ends_on
      category_id
    ].freeze

    belongs_to :user
    belongs_to :category, class_name: "Financial::Category", optional: true

    has_many :transactions,
             class_name: "Financial::Transaction",
             foreign_key: :recurrence_rule_id,
             dependent:   :nullify,
             inverse_of:  :recurrence_rule

    enum transaction_type: { expense: "expense", income: "income" }, _prefix: :type
    enum frequency:        FREQUENCIES, _prefix: :frequency

    validates :amount,           presence: true, numericality: { greater_than: 0 }
    validates :transaction_type, presence: true
    validates :starts_on,        presence: true
    validates :day_of_month,     numericality: { in: 1..31, only_integer: true }, allow_nil: true
    validate  :ends_on_after_starts_on

    scope :active_only, -> { where(active: true) }

    # Active rules that cover the given competency month.
    scope :covering_month, ->(month) {
      d = month.beginning_of_month
      active_only
        .where("starts_on <= ?", d.end_of_month)
        .where("ends_on IS NULL OR ends_on >= ?", d)
    }

    private

    def ends_on_after_starts_on
      return if ends_on.blank? || starts_on.blank?

      errors.add(:ends_on, "must be after starts_on") if ends_on < starts_on
    end
  end
end
