# frozen_string_literal: true

module Support
  class TransactionScope
    # @param [User]
    # @param [String, nil]
    # @param [String, nil]
    # @param [String, nil]
    # @param [String, nil]
    # @param [Date, String, nil]
    # @param [Date, String, nil]
    # @return [ActiveRecord::Relation<Financial::Transaction>]
    def call(user:, category_id: nil, transaction_type: nil, status: nil,
             payer_phone: nil, from: nil, to: nil)
      user.transactions
          .by_category(category_id)
          .by_type(transaction_type)
          .by_status(status)
          .by_payer_phone(payer_phone)
          .competency_from(Support::DateParser.parse_month(from))
          .competency_until(Support::DateParser.parse_month(to))
    end
  end
end
