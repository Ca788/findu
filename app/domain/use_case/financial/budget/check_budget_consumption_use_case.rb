# frozen_string_literal: true

class UseCase::Financial::Budget::CheckBudgetConsumptionUseCase
  WARNING_PERCENT = 80.0

  # @param [User] user
  # @param [Time, DateTime, Date, String, nil] occurred_at
  # @return [Array<Hash>]
  def call(user:, occurred_at: nil)
    reference_date = resolve_date(occurred_at)

    user.budgets.covering(reference_date).each_with_object([]) do |budget, acc|
      percent = budget.usage_percent
      next if percent < WARNING_PERCENT

      acc << build_warning(budget, percent)
    end
  end

  private

  # @param [Object, nil] value
  # @return [Date]
  def resolve_date(value)
    return Date.current if value.blank?

    value.to_date
  rescue NoMethodError, Date::Error, ArgumentError, TypeError
    Date.current
  end

  # @param [Financial::Budget] budget
  # @param [Float] percent
  # @return [Hash]
  def build_warning(budget, percent)
    {
      budget_id:     budget.id,
      period_type:   budget.period_type,
      period_start:  budget.period_start,
      period_end:    budget.period_end,
      limit_amount:  budget.limit_amount,
      spent_amount:  budget.spent_amount,
      remaining:     budget.remaining,
      usage_percent: percent,
      status:        percent > 100.0 ? "exceeded" : "warning"
    }
  end
end
