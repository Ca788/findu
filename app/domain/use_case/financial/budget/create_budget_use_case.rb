# frozen_string_literal: true

class UseCase::Financial::Budget::CreateBudgetUseCase
  # @param [User] user
  # @param [Hash] attributes — keys among Financial::Budget::PERMITTED_ATTRIBUTES
  # @return [Financial::Budget]
  def call(user:, attributes:)
    user.budgets.create!(attributes.symbolize_keys.slice(*Financial::Budget::PERMITTED_ATTRIBUTES))
  end
end
