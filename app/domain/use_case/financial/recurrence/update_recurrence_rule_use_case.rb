# frozen_string_literal: true

class UseCase::Financial::Recurrence::UpdateRecurrenceRuleUseCase
  # Atualiza os atributos da regra e reflete os novos valores APENAS nas
  # transactions futuras com status "pending". Transactions "paid" não são
  # tocadas (preservam o histórico realizado).
  #
  # @param [User]
  # @param [String] rule id
  # @param [Hash]
  # @return [Financial::RecurrenceRule]
  def call(user:, id:, attributes:)
    rule = user.recurrence_rules.find(id)
    permitted = attributes.symbolize_keys.slice(*::Financial::RecurrenceRule::PERMITTED_ATTRIBUTES)

    ApplicationRecord.transaction do
      rule.update!(permitted)
      propagate_to_future_pending(rule, permitted)
      UseCase::Financial::Recurrence::MaterializeRecurrenceRuleUseCase.new.call(rule: rule)
    end

    rule
  end

  private

  def propagate_to_future_pending(rule, permitted)
    future = rule.transactions
                 .where(status: "pending")
                 .where("competency_month >= ?", Date.current.beginning_of_month)

    payload = {}
    payload[:amount]           = permitted[:amount]           if permitted.key?(:amount)
    payload[:description]      = permitted[:description]      if permitted.key?(:description)
    payload[:category_id]      = permitted[:category_id]      if permitted.key?(:category_id)
    payload[:transaction_type] = permitted[:transaction_type] if permitted.key?(:transaction_type)

    future.update_all(payload.merge(updated_at: Time.current)) if payload.any?
  end
end
