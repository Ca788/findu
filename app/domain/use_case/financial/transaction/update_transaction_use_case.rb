# frozen_string_literal: true

class UseCase::Financial::Transaction::UpdateTransactionUseCase
  # @param [User] user
  # @param [String] id
  # @param [BigDecimal, Numeric, String, nil] amount
  # @param [String, nil] transaction_type
  # @param [String, nil] description
  # @param [DateTime, String, nil] occurred_at
  # @param [String, nil] category_id
  # @param [Hash, nil] metadata
  # @return [Financial::Transaction]
  def call(user:, id:, amount: nil, transaction_type: nil, description: nil, occurred_at: nil, category_id: nil, metadata: nil)
    transaction = user.transactions.find(id)

    attributes = {
      amount: amount,
      transaction_type: transaction_type,
      description: description,
      occurred_at: occurred_at,
      metadata: metadata
    }.compact

    attributes[:category] = resolve_category(user, category_id) unless category_id.nil?

    transaction.update!(attributes)
    transaction.budget_warnings = budget_warnings_for(transaction)
    transaction
  end

  private

  # @param [Financial::Transaction] transaction
  # @return [Array<Hash>]
  def budget_warnings_for(transaction)
    return [] unless transaction.expense?

    UseCase::Financial::Budget::CheckBudgetConsumptionUseCase.new.call(
      user:        transaction.user,
      occurred_at: transaction.occurred_at
    )
  end


  # @param [User] user
  # @param [String, nil] id
  # @return [Financial::Category, nil]
  def resolve_category(user, id)
    return nil if id.blank?

    user.categories.find(id)
  end
end
