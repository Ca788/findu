# frozen_string_literal: true

class UseCase::Financial::Recurrence::CreateRecurrenceRuleUseCase
  # @param [User]
  # @param [Hash] attributes
  # @return [Financial::RecurrenceRule]
  def call(user:, attributes:)
    rule = nil

    ApplicationRecord.transaction do
      rule = user.recurrence_rules.create!(
        attributes.symbolize_keys.slice(*::Financial::RecurrenceRule::PERMITTED_ATTRIBUTES)
      )

      UseCase::Financial::Recurrence::MaterializeRecurrenceRuleUseCase.new.call(rule: rule)
    end

    rule
  end
end
