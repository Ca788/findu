# frozen_string_literal: true

class UseCase::Financial::Statements::ShowMonthlyStatementUseCase
  Statement = Struct.new(
    :month,
    :forecast,
    :actual,
    :counts,
    :entries,
    :installments_active,
    :recurrences_active,
    :by_category,
    keyword_init: true
  )

  ByCategory = Struct.new(:category_id, :category_name, :forecast, :paid, keyword_init: true)

  UNCATEGORIZED_LABEL = "Uncategorized"

  # @param [User]
  # @param [Date, String, nil] month accepts "YYYY-MM" or Date; defaults to current month
  # @return [Statement]
  def call(user:, month: nil)
    reference = resolve_month(month)

    entries = user.transactions
                  .includes(:category, :installment_plan, :recurrence_rule)
                  .in_competency(reference)
                  .order(:paid_at, :created_at)
                  .to_a

    Statement.new(
      month:               reference.strftime("%Y-%m"),
      forecast:            forecast_totals(entries),
      actual:              actual_totals(entries),
      counts:              counts(entries),
      entries:             entries,
      installments_active: installments_active(user, reference),
      recurrences_active:  recurrences_active(user, reference),
      by_category:         aggregate_by_category(entries)
    )
  end

  private

  # @param [Object, nil] value accepts "YYYY-MM", "YYYY-MM-DD", Date, or nil
  # @return [Date]
  def resolve_month(value)
    if value.is_a?(String) && value.match?(/\A\d{4}-\d{2}\z/)
      year, month = value.split("-").map(&:to_i)
      return Date.new(year, month, 1)
    end

    parsed = Support::DateParser.parse(value) || Date.current
    parsed.beginning_of_month
  end

  # @param [Array<Financial::Transaction>] entries
  def forecast_totals(entries)
    income  = sum_by_type(entries, "income")
    expense = sum_by_type(entries, "expense")
    { income: income, expense: expense, balance: income - expense }
  end

  def actual_totals(entries)
    paid    = entries.select { |e| e.status == "paid" }
    income  = sum_by_type(paid, "income")
    expense = sum_by_type(paid, "expense")
    { income_paid: income, expense_paid: expense, balance: income - expense }
  end

  def sum_by_type(list, type)
    list.select { |e| e.transaction_type == type }.sum { |e| e.amount || 0 }
  end

  def counts(entries)
    {
      pending: entries.count { |e| e.status == "pending" },
      paid:    entries.count { |e| e.status == "paid" },
      total:   entries.size
    }
  end

  def installments_active(user, reference)
    user.installment_plans
        .where(status: "active")
        .where("first_competency <= ?", reference)
        .where(
          "first_competency + ((total_installments - 1) * INTERVAL '1 month') >= ?",
          reference
        )
        .to_a
  end

  def recurrences_active(user, reference)
    user.recurrence_rules.covering_month(reference).to_a
  end

  def aggregate_by_category(entries)
    grouped = entries.group_by(&:category_id)

    grouped.map do |category_id, list|
      name = list.first.category&.name || UNCATEGORIZED_LABEL
      ByCategory.new(
        category_id:   category_id,
        category_name: name,
        forecast:      list.sum { |e| e.amount || 0 },
        paid:          list.select { |e| e.status == "paid" }.sum { |e| e.amount || 0 }
      )
    end.sort_by { |row| -row.forecast.to_f }
  end
end
