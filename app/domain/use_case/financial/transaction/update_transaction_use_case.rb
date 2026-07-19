# frozen_string_literal: true

class UseCase::Financial::Transaction::UpdateTransactionUseCase
  # @param [User] user
  # @param [String] id
  # @param [BigDecimal, Numeric, String, nil] amount
  # @param [String, nil] transaction_type
  # @param [String, nil] description
  # @param [DateTime, String, nil] occurred_at
  # @param [Date, String, nil] competency_month
  # @param [String, nil] status
  # @param [String, nil] category_id
  # @param [Hash, nil] metadata
  # @return [Financial::Transaction]
  def call(user:, id:, amount: nil, transaction_type: nil, description: nil,
           occurred_at: nil, competency_month: nil, status: nil,
           category_id: nil, metadata: nil)
    transaction = user.transactions.find(id)

    attributes = {
      amount:           amount,
      transaction_type: transaction_type,
      description:      description,
      occurred_at:      occurred_at,
      status:           status,
      metadata:         metadata
    }.compact

    if competency_month.present?
      parsed = Support::DateParser.parse(competency_month)
      attributes[:competency_month] = parsed.beginning_of_month if parsed
    end

    attributes[:category] = resolve_category(user, category_id) unless category_id.nil?

    transaction.update!(attributes)
    transaction.budget_warnings = budget_warnings_for(transaction)
    transaction
  end

  private

  def budget_warnings_for(transaction)
    return [] unless transaction.expense?

    UseCase::Financial::Budget::CheckBudgetConsumptionUseCase.new.call(
      user:        transaction.user,
      occurred_at: transaction.occurred_at || transaction.competency_month
    )
  end

  def resolve_category(user, id)
    return nil if id.blank?

    user.categories.find(id)
  end
end
