# frozen_string_literal: true

class UseCase::Financial::Recurrence::CancelRecurrenceRuleUseCase
  # Deactivates the rule and deletes only future pending occurrences.
  # Paid or past occurrences keep the history.
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
