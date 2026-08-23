# == Schema Information
#
# Table name: transactions
#
#  id                  :uuid             not null, primary key
#  amount              :decimal(10, 2)   not null
#  competency_month    :date             not null
#  description         :string
#  installment_number  :integer
#  metadata            :jsonb
#  occurred_at         :datetime
#  paid_at             :datetime
#  payer_name          :string
#  payer_phone         :string
#  status              :string           default("pending"), not null
#  transaction_type    :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  artifact_id         :uuid
#  category_id         :uuid
#  installment_plan_id :uuid
#  recurrence_rule_id  :uuid
#  user_id             :uuid             not null
#
# Indexes
#
#  index_transactions_on_artifact_id                   (artifact_id)
#  index_transactions_on_category_id                   (category_id)
#  index_transactions_on_installment_plan_id           (installment_plan_id)
#  index_transactions_on_recurrence_rule_id            (recurrence_rule_id)
#  index_transactions_on_user_id                       (user_id)
#  index_transactions_on_user_id_and_competency_month  (user_id,competency_month)
#  index_transactions_on_user_id_and_payer_phone       (user_id,payer_phone)
#  index_transactions_on_user_id_and_status            (user_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (artifact_id => artifacts.id)
#  fk_rails_...  (category_id => categories.id)
#  fk_rails_...  (installment_plan_id => installment_plans.id)
#  fk_rails_...  (recurrence_rule_id => recurrence_rules.id)
#  fk_rails_...  (user_id => users.id)
#
module Financial
  class Transaction < ApplicationRecord

    PERMITTED_ATTRIBUTES = %i[
      amount
      transaction_type
      description
      occurred_at
      competency_month
      status
      category_id
      payer_name
      payer_phone
      metadata
    ].freeze

    CREATE_ONLY_ATTRIBUTES = %i[category_name].freeze
    STATUSES = { pending: "pending", paid: "paid" }.freeze
    SOURCE_MANUAL      = "manual"
    SOURCE_RECURRENCE  = "recurrence"
    SOURCE_INSTALLMENT = "installment"

    belongs_to :user
    belongs_to :artifact,         optional: true
    belongs_to :category,         class_name: "Financial::Category",       optional: true
    belongs_to :recurrence_rule,  class_name: "Financial::RecurrenceRule", optional: true
    belongs_to :installment_plan, class_name: "Financial::InstallmentPlan", optional: true

    enum transaction_type: { expense: "expense", income: "income" }
    enum status:           STATUSES, _prefix: :status

    attr_writer :budget_warnings

    def budget_warnings
      @budget_warnings ||= []
    end

    validates :amount, presence: true, numericality: { greater_than: 0 }
    validates :transaction_type, presence: true
    validates :competency_month, presence: true

    before_validation :normalize_competency_month
    before_validation :apply_paid_at_from_status

    scope :by_type,        ->(type)        { where(transaction_type: type) if type.present? }
    scope :by_category,    ->(category_id) { where(category_id: category_id) if category_id.present? }
    scope :by_status,      ->(status)      { where(status: status) if status.present? }
    scope :by_payer_phone, ->(phone)       { where(payer_phone: phone) if phone.present? }
    scope :occurred_from,  ->(from)        { where("occurred_at >= ?", from) if from.present? }
    scope :occurred_until, ->(to)          { where("occurred_at <= ?", to) if to.present? }

    scope :competency_from,  ->(date) { where(competency_month: date.beginning_of_month..) if date.present? }
    scope :competency_until, ->(date) { where(competency_month: ..date.beginning_of_month) if date.present? }
    scope :uncategorized,    -> { where(category_id: nil) }

    scope :in_competency,  ->(date) {
      d = date.is_a?(String) ? Date.parse(date) : date.to_date
      where(competency_month: d.beginning_of_month)
    }
    scope :in_competency_range, ->(from, to) {
      where(competency_month: from.beginning_of_month..to.beginning_of_month)
    }
    scope :paid,    -> { where(status: "paid") }
    scope :pending, -> { where(status: "pending") }

    # @return [String] one of SOURCE_* constants
    def source
      return SOURCE_INSTALLMENT if installment_plan_id.present?
      return SOURCE_RECURRENCE  if recurrence_rule_id.present?

      SOURCE_MANUAL
    end

    private

    def normalize_competency_month
      return if competency_month.blank?
      return if competency_month.day == 1

      self.competency_month = competency_month.beginning_of_month
    end

    def apply_paid_at_from_status
      if status_paid? && paid_at.blank?
        self.paid_at = Time.current
      elsif status_pending? && paid_at.present?
        self.paid_at = nil
      end
    end
  end
end
