# frozen_string_literal: true

class UseCase::Financial::Category::ListCategoryTotalsUseCase
  Total = Struct.new(
    :category_id,
    :category_name,
    :income,
    :expense,
    :balance,
    :paid_amount,
    :pending_amount,
    :transactions_count,
    keyword_init: true
  ) do
    # @return [BigDecimal]
    def total
      income + expense
    end
  end

  UNCATEGORIZED_LABEL = "Uncategorized"

  SUM_INCOME  = "COALESCE(SUM(CASE WHEN transactions.transaction_type = 'income'  THEN transactions.amount END), 0)"
  SUM_EXPENSE = "COALESCE(SUM(CASE WHEN transactions.transaction_type = 'expense' THEN transactions.amount END), 0)"
  SUM_PAID    = "COALESCE(SUM(CASE WHEN transactions.status = 'paid'    THEN transactions.amount END), 0)"
  SUM_PENDING = "COALESCE(SUM(CASE WHEN transactions.status = 'pending' THEN transactions.amount END), 0)"

  # @param [Support::TransactionScope]
  def initialize(scope: Support::TransactionScope.new)
    @scope = scope
  end

  # @param [User]
  # @param [Date, String, nil]
  # @param [Date, String, nil]
  # @param [String, nil]
  # @param [String, nil]
  # @param [String, nil]
  # @return [Array<Total>]
  def call(user:, from: nil, to: nil, transaction_type: nil, status: nil, payer_phone: nil)
    rows = @scope.call(
      user:             user,
      from:             from,
      to:               to,
      transaction_type: transaction_type,
      status:           status,
      payer_phone:      payer_phone
    ).left_joins(:category)
     .group("categories.id", "categories.name")
     .pluck(
       Arel.sql("categories.id"),
       Arel.sql("categories.name"),
       Arel.sql(SUM_INCOME),
       Arel.sql(SUM_EXPENSE),
       Arel.sql(SUM_PAID),
       Arel.sql(SUM_PENDING),
       Arel.sql("COUNT(transactions.id)")
     )

    rows.map { |row| build_total(row) }.sort_by { |row| -row.total }
  end

  private

  # @param [Array]
  # @return [Total]
  def build_total(row)
    id, name, income, expense, paid, pending, count = row

    Total.new(
      category_id:        id,
      category_name:      name || UNCATEGORIZED_LABEL,
      income:             income,
      expense:            expense,
      balance:            income - expense,
      paid_amount:        paid,
      pending_amount:     pending,
      transactions_count: count
    )
  end
end
