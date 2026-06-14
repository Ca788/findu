# frozen_string_literal: true

class UseCase::Financial::Transaction::ListTransactionsUseCase
  DEFAULT_LIMIT = 25
  MAX_LIMIT     = 100

  # @param [User] user
  # @param [String, nil]
  # @param [String, nil]
  # @param [Date, String, nil]
  # @param [Date, String, nil]
  # @param [String, nil]
  # @param [Integer, nil]
  # @param [Integer, nil]
  # @return [ActiveRecord::Relation<Financial::Transaction>]
  def call(user:,
           transaction_type: nil,
           category_id: nil,
           from: nil,
           to: nil,
           description_like: nil,
           limit: nil,
           offset: nil)
    scope = user.transactions
                .includes(:category)
                .by_type(transaction_type)
                .by_category(category_id)
                .occurred_from(Support::DateParser.parse(from)&.beginning_of_day)
                .occurred_until(Support::DateParser.parse(to)&.end_of_day)

    scope = scope.where("description ILIKE ?", "%#{description_like.strip}%") if description_like.is_a?(String) && description_like.strip.present?

    scope.order(occurred_at: :desc, created_at: :desc)
         .limit(clamp_limit(limit))
         .offset(offset.to_i.clamp(0, Float::INFINITY))
  end

  private

  def clamp_limit(value)
    n = value.to_i
    return DEFAULT_LIMIT if n <= 0

    [n, MAX_LIMIT].min
  end
end
