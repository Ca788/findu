# frozen_string_literal: true

class UseCase::Financial::Transaction::DestroyTransactionUseCase
  # @param [User]
  # @param [String]
  # @return [Financial::Transaction]
  def call(user:, id:)
    transaction = user.transactions.find(id)
    transaction.destroy!
    transaction
  end
end
