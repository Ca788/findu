# frozen_string_literal: true

class UseCase::Financial::Transaction::CreateTransactionUseCase
  # @param [User] user
  # @param [BigDecimal, Numeric, String] amount
  # @param [String] transaction_type
  # @param [String, nil] description
  # @param [DateTime, String, nil] occurred_at
  # @param [String, nil] category_id
  # @param [String, nil] artifact_id
  # @param [Hash, nil] metadata
  # @return [Financial::Transaction]
  def call(user:, amount:, transaction_type:, description: nil, occurred_at: nil, category_id: nil, artifact_id: nil, metadata: nil)
    category = resolve_category(user, category_id)
    artifact = resolve_artifact(user, artifact_id)

    user.transactions.create!(
      amount: amount,
      transaction_type: transaction_type,
      description: description,
      occurred_at: occurred_at,
      category: category,
      artifact: artifact,
      metadata: metadata
    )
  end

  private

  # @param [User] user
  # @param [String, nil] id
  # @return [Financial::Category, nil]
  def resolve_category(user, id)
    return nil if id.blank?

    user.categories.find(id)
  end

  # @param [User] user
  # @param [String, nil] id
  # @return [Artifact, nil]
  def resolve_artifact(user, id)
    return nil if id.blank?

    user.artifacts.find(id)
  end
end
