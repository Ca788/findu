# frozen_string_literal: true

class UseCase::Financial::Statements::ListStatementsUseCase
  Summary = Struct.new(
    :month,
    :income_forecast,
    :expense_forecast,
    :balance_forecast,
    :income_paid,
    :expense_paid,
    :balance_actual,
    :pending_count,
    :paid_count,
    keyword_init: true
  )

  DEFAULT_WINDOW_MONTHS = 12

  # @param [User]
  # @param [Date, String, nil] from
  # @param [Date, String, nil] to
  # @return [Array<Summary>]
  def call(user:, from: nil, to: nil)
    range_from = Support::DateParser.parse(from)&.beginning_of_month
    range_to   = Support::DateParser.parse(to)&.beginning_of_month

    range_from ||= Date.current.beginning_of_month - (DEFAULT_WINDOW_MONTHS - 1).months
    range_to   ||= Date.current.beginning_of_month + DEFAULT_WINDOW_MONTHS.months

    aggregates_by_month = aggregate(user, range_from, range_to)

    months_in(range_from, range_to).map do |month|
      row = aggregates_by_month[month] || empty_row
      Summary.new(
        month:            month.strftime("%Y-%m"),
        income_forecast:  row[:income_forecast],
        expense_forecast: row[:expense_forecast],
        balance_forecast: row[:income_forecast] - row[:expense_forecast],
        income_paid:      row[:income_paid],
        expense_paid:     row[:expense_paid],
        balance_actual:   row[:income_paid] - row[:expense_paid],
        pending_count:    row[:pending_count],
        paid_count:       row[:paid_count]
      )
    end
  end

  private

  def aggregate(user, from, to)
    rows = user.transactions
               .in_competency_range(from, to)
               .group(:competency_month, :transaction_type, :status)
               .pluck(:competency_month, :transaction_type, :status, "SUM(amount)", "COUNT(*)")

    accumulator = Hash.new { |h, k| h[k] = empty_row }

    rows.each do |month, type, status, amount, count|
      row = accumulator[month]

      if type == "income"
        row[:income_forecast] += amount
        row[:income_paid]     += amount if status == "paid"
      else
        row[:expense_forecast] += amount
        row[:expense_paid]     += amount if status == "paid"
      end

      if status == "paid"
        row[:paid_count] += count
      else
        row[:pending_count] += count
      end
    end

    accumulator
  end

  def months_in(from, to)
    result = []
    cursor = from
    while cursor <= to
      result << cursor
      cursor = cursor.next_month
    end
    result
  end

  def empty_row
    {
      income_forecast:  0.to_d,
      expense_forecast: 0.to_d,
      income_paid:      0.to_d,
      expense_paid:     0.to_d,
      pending_count:    0,
      paid_count:       0
    }
  end
end
