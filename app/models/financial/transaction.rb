# == Schema Information
#
# Table name: transactions
#
#  id               :uuid             not null, primary key
#  amount           :decimal(10, 2)   not null
#  description      :string
#  metadata         :jsonb
#  occurred_at      :datetime
#  transaction_type :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  artifact_id      :uuid
#  category_id      :uuid
#  organization_id  :uuid             not null
#  user_id          :uuid             not null
#
# Indexes
#
#  index_transactions_on_artifact_id      (artifact_id)
#  index_transactions_on_category_id      (category_id)
#  index_transactions_on_organization_id  (organization_id)
#  index_transactions_on_user_id          (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (artifact_id => artifacts.id)
#  fk_rails_...  (category_id => categories.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (user_id => users.id)
#
module Financial
  class Transaction < ApplicationRecord
    belongs_to :organization
    belongs_to :user
    belongs_to :artifact, optional: true
    belongs_to :category, class_name: "Financial::Category", optional: true

    has_many :installments, class_name: "Financial::Installment", foreign_key: :transaction_id

    enum transaction_type: { expense: "expense", income: "income" }

    validates :amount, presence: true
    validates :transaction_type, presence: true
  end
end
