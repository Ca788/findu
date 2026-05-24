# frozen_string_literal: true

class UseCase::Financial::Installment::CreateInstallmentUseCase
  PERMITTED_ATTRIBUTES = %i[
    total_amount
    total_installments
    current_installment
    monthly_amount
    started_at
  ].freeze

  # @param [User]
  # @param [String]
  # @param [Hash]
  # @return [Financial::Installment]
  def call(user:, transaction_id:, attributes:)
    transaction = user.transactions.find(transaction_id)

    transaction.installments.create!(
      attributes.symbolize_keys.slice(*PERMITTED_ATTRIBUTES)
    )
  end
end
