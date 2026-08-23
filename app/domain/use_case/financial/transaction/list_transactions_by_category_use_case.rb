# frozen_string_literal: true

class UseCase::Financial::Transaction::ListTransactionsByCategoryUseCase
  # @param [Support::TransactionScope]
  def initialize(scope: Support::TransactionScope.new)
    @scope = scope
  end

  # @param [User]
  # @param [String]
  # @param [Date, String, nil]
  # @param [Date, String, nil]
  # @param [String, nil]
  # @param [String, nil]
  # @param [String, nil]
  # @raise [ActiveRecord::RecordNotFound]
  # @return [ActiveRecord::Relation<Financial::Transaction>]
  def call(user:, category_id:, from: nil, to: nil,
           transaction_type: nil, status: nil, payer_phone: nil)
    category = user.categories.find(category_id)

    @scope.call(
      user:             user,
      category_id:      category.id,
      from:             from,
      to:               to,
      transaction_type: transaction_type,
      status:           status,
      payer_phone:      payer_phone
    ).includes(:category)
     .order(competency_month: :desc, occurred_at: :desc, created_at: :desc)
  end
end
