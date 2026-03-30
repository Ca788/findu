# == Schema Information
#
# Table name: installments
#
#  id                  :uuid             not null, primary key
#  current_installment :integer
#  monthly_amount      :decimal(10, 2)
#  started_at          :datetime
#  total_amount        :decimal(10, 2)
#  total_installments  :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  transaction_id      :uuid             not null
#
# Indexes
#
#  index_installments_on_transaction_id  (transaction_id)
#
# Foreign Keys
#
#  fk_rails_...  (transaction_id => transactions.id)
#
module Financial
  class Installment < ApplicationRecord
    belongs_to :financial_transaction, class_name: "Financial::Transaction", foreign_key: :transaction_id

    validates :total_installments, numericality: { only_integer: true, greater_than: 0 }
  end
end
