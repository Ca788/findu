# == Schema Information
#
# Table name: budgets
#
#  id           :uuid             not null, primary key
#  deleted_at   :datetime
#  limit_amount :decimal(10, 2)
#  period_end   :date             not null
#  period_start :date             not null
#  period_type  :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :uuid             not null
#
# Indexes
#
#  index_budgets_on_period_type         (period_type)
#  index_budgets_on_user_id             (user_id)
#  index_budgets_on_user_id_and_period  (user_id,period_start,period_end) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
module Financial
  class Budget < ApplicationRecord
    PERMITTED_ATTRIBUTES = %i[
      period_type
      period_start
      period_end
      limit_amount
    ].freeze

    PERIOD_TYPES = {
      weekly:  "weekly",
      monthly: "monthly",
      yearly:  "yearly",
      custom:  "custom"
    }.freeze

    belongs_to :user

    enum period_type: PERIOD_TYPES

    validates :period_type, presence: true
    validates :period_start, presence: true
    validates :period_end, presence: true, comparison: { greater_than: :period_start, if: :period_start? }
    validates :limit_amount, presence: true, numericality: { greater_than: 0 }
    validates :period_start, uniqueness: { scope: [:user_id, :period_end] }

    scope :covering, ->(date) { where("period_start <= :date AND period_end >= :date", date: date) }
    scope :for_period_type, ->(type) { where(period_type: type) if type.present? }

    # @return [BigDecimal]
    def spent_amount
      @spent_amount ||= user.transactions
                            .where(transaction_type: "expense")
                            .where(occurred_at: period_range)
                            .sum(:amount)
    end

    # @return [BigDecimal]
    def remaining
      (limit_amount || 0) - spent_amount
    end

    # @return [Float]
    def usage_percent
      return 0.0 if limit_amount.to_f.zero?

      ((spent_amount.to_f / limit_amount.to_f) * 100).round(2)
    end

    def reload_usage
      @spent_amount = nil
      self
    end

    private

    def period_range
      period_start.beginning_of_day..period_end.end_of_day
    end
  end
end
