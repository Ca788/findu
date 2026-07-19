# frozen_string_literal: true

class UseCase::Financial::Statements::MarkPaidUseCase
  # @param [User]
  # @param [String] transaction id
  # @param [DateTime, String, nil] paid_at defaults to Time.current
  # @return [Financial::Transaction]
  def call(user:, id:, paid_at: nil)
    transaction = user.transactions.find(id)

    transaction.update!(
      status:  "paid",
      paid_at: Support::DateParser.parse(paid_at) || Time.current
    )

    transaction
  end
end
