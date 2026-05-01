# frozen_string_literal: true

class UseCase::Artifact::CreateTransactionFromArtifactUseCase
  # @param [Artifact] artifact
  # @return [Financial::Transaction]
  def call(artifact:)
    return artifact.financial_transaction if artifact.financial_transaction.present?

    data = artifact.processed_data
    raise ArgumentError, "artifact has no processed data" if data.blank?
    raise ArgumentError, "amount is required to create transaction" if data["amount"].blank?

    UseCase::Financial::Transaction::CreateTransactionUseCase.new.call(
      user: artifact.user,
      amount: BigDecimal(data["amount"]),
      transaction_type: data["transaction_type"] || "expense",
      description: data["description"],
      occurred_at: artifact.occurred_at,
      artifact_id: artifact.id,
      metadata: data["metadata"]
    )
  end
end
