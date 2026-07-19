# frozen_string_literal: true

class UseCase::Financial::Recurrence::CancelRecurrenceRuleUseCase
  # Desativa a regra e remove APENAS ocorrências futuras "pending".
  # Ocorrências "paid" ou de meses passados preservam o histórico.
  #
  # @param [User]
  # @param [String] rule id
  # @return [Financial::RecurrenceRule]
  def call(user:, id:)
    rule = user.recurrence_rules.find(id)

    ApplicationRecord.transaction do
      rule.update!(active: false, canceled_at: Time.current)

      rule.transactions
          .where(status: "pending")
          .where("competency_month >= ?", Date.current.beginning_of_month)
          .destroy_all
    end

    rule
  end
end
