# frozen_string_literal: true

class UseCase::Financial::SummaryUseCase
  Result = Struct.new(
    :from,
    :to,
    :total_amount,
    :transaction_count,
    :by_type,
    :by_category,
    keyword_init: true
  )

  CategoryBreakdown = Struct.new(:category_id, :category_name, :amount, keyword_init: true)

  TRANSACTION_TYPES = %w[expense income].freeze
  UNCATEGORIZED_LABEL = "Uncategorized"

  # @param [User]
  # @param [Date, String, nil]
  # @param [Date, String, nil]
  # @param [String, nil]
  # @param [String, nil]
  # @return [Result]
  def call(user:, from: nil, to: nil, transaction_type: nil, category_id: nil)
    period_from = Support::DateParser.parse(from) || Date.current.beginning_of_month
    period_to   = Support::DateParser.parse(to)   || Date.current.end_of_month

    scope = filtered_transactions(user, period_from, period_to, transaction_type, category_id)

    Result.new(
      from:              period_from,
      to:                period_to,
      total_amount:      scope.sum(:amount),
      transaction_count: scope.count,
      by_type:           aggregate_by_type(scope),
      by_category:       aggregate_by_category(scope)
    )
  end

  private

  def filtered_transactions(user, from, to, transaction_type, category_id)
    scope = user.transactions.where(occurred_at: from.beginning_of_day..to.end_of_day)
    scope = scope.where(transaction_type: transaction_type) if transaction_type.present?
    scope = scope.where(category_id: category_id)           if category_id.present?
    scope
  end

  def aggregate_by_type(scope)
    totals = scope.group(:transaction_type).sum(:amount)
    TRANSACTION_TYPES.index_with { |type| totals[type] || 0 }
  end

  def aggregate_by_category(scope)
    rows = scope
             .left_joins(:category)
             .select(
               "transactions.category_id",
               "COALESCE(categories.name, '#{UNCATEGORIZED_LABEL}') AS category_name",
               "SUM(transactions.amount) AS total_amount"
             )
             .group("transactions.category_id", "categories.name")
             .order("total_amount DESC")

    rows.map do |row|
      CategoryBreakdown.new(
        category_id: row.category_id,
        category_name: row.category_name,
        amount: row.total_amount
      )
    end
  end
end
