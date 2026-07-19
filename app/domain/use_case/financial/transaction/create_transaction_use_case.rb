# frozen_string_literal: true

class UseCase::Financial::Transaction::CreateTransactionUseCase
  # @param [User] user
  # @param [BigDecimal, Numeric, String] amount
  # @param [String] transaction_type
  # @param [String, nil] description
  # @param [DateTime, String, nil] occurred_at
  # @param [Date, String, nil] competency_month accepts "YYYY-MM" or Date; defaults to current month
  # @param [String, nil] status "pending" (default) or "paid"
  # @param [String, nil] category_id
  # @param [String, nil] artifact_id
  # @param [Hash, nil] metadata
  # @return [Financial::Transaction]
  def call(user:, amount:, transaction_type:,
           description: nil, occurred_at: nil,
           competency_month: nil, status: "pending",
           category_id: nil, artifact_id: nil, metadata: nil)
    category = resolve_category(user, category_id)
    artifact = resolve_artifact(user, artifact_id)

    transaction = user.transactions.create!(
      amount:           amount,
      transaction_type: transaction_type,
      description:      description,
      occurred_at:      occurred_at,
      competency_month: resolve_competency(competency_month, occurred_at),
      status:           status.presence || "pending",
      category:         category,
      artifact:         artifact,
      metadata:         metadata
    )

    transaction.budget_warnings = budget_warnings_for(transaction)
    transaction
  end

  private

  # @return [Date]
  def resolve_competency(explicit, occurred_at)
    parsed = Support::DateParser.parse(explicit) || Support::DateParser.parse(occurred_at)
    (parsed || Date.current).beginning_of_month
  end

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

  def resolve_artifact(user, id)
    return nil if id.blank?

    user.artifacts.find(id)
  end
end
