# frozen_string_literal: true

class UseCase::Financial::Statements::MarkPendingUseCase
  # @param [User]
  # @param [String] transaction id
  # @return [Financial::Transaction]
  def call(user:, id:)
    transaction = user.transactions.find(id)
    transaction.update!(status: "pending", paid_at: nil)
    transaction
  end
end
