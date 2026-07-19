# == Schema Information
#
# Table name: installment_plans
#
#  id                  :uuid             not null, primary key
#  canceled_at         :datetime
#  current_installment :integer
#  description         :string
#  first_competency    :date
#  monthly_amount      :decimal(10, 2)
#  started_at          :datetime
#  status              :string           default("active"), not null
#  total_amount        :decimal(10, 2)
#  total_installments  :integer
#  transaction_type    :string           default("expense"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  category_id         :uuid
#  user_id             :uuid
#
# Indexes
#
#  index_installment_plans_on_category_id         (category_id)
#  index_installment_plans_on_user_id             (user_id)
#  index_installment_plans_on_user_id_and_status  (user_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#  fk_rails_...  (user_id => users.id)
#
module Financial
  class InstallmentPlan < ApplicationRecord
    STATUSES = { active: "active", completed: "completed", canceled: "canceled" }.freeze

    PERMITTED_ATTRIBUTES = %i[
      description
      transaction_type
      category_id
      total_installments
      monthly_amount
      first_competency
    ].freeze

    belongs_to :user
    belongs_to :category, class_name: "Financial::Category", optional: true

    has_many :transactions,
             -> { order(:competency_month) },
             class_name: "Financial::Transaction",
             foreign_key: :installment_plan_id,
             dependent:   :nullify,
             inverse_of:  :installment_plan

    enum status:           STATUSES, _prefix: :status
    enum transaction_type: { expense: "expense", income: "income" }, _prefix: :type

    validates :total_installments, presence: true,
              numericality: { only_integer: true, greater_than: 0 }
    validates :monthly_amount, presence: true, numericality: { greater_than: 0 }
    validates :first_competency, presence: true

    # @return [Integer]
    def paid_count
      transactions.where(status: "paid").count
    end

    # @return [Integer]
    def remaining_count
      total_installments.to_i - paid_count
    end

    # @return [BigDecimal]
    def paid_amount
      transactions.where(status: "paid").sum(:amount)
    end

    # @return [BigDecimal]
    def remaining_amount
      (total_amount_derived || 0) - paid_amount
    end

    # @return [BigDecimal]
    def total_amount_derived
      total_amount.presence || (monthly_amount.to_d * total_installments.to_i)
    end

    # @return [Date, nil]
    def end_competency
      return nil if first_competency.blank? || total_installments.to_i.zero?

      first_competency + (total_installments.to_i - 1).months
    end

    def completed?
      status_completed? || (transactions.any? && remaining_count <= 0)
    end
  end
end
