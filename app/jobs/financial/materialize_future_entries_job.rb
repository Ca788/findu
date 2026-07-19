# frozen_string_literal: true

module Financial
  # Diário. Garante que:
  #   - Cada recurrence rule ativa tem 12 meses de transactions materializadas à frente.
  #   - Cada installment plan ativo com todas as parcelas fecha para "completed" quando
  #     todas as N transactions estiverem pagas.
  #
  # Não recria transactions removidas manualmente pelo usuário no passado (< mês corrente).
  class MaterializeFutureEntriesJob < ApplicationJob
    queue_as :default

    def perform
      materialize_recurrences
      complete_installment_plans
    end

    private

    def materialize_recurrences
      Financial::RecurrenceRule.active_only.find_each do |rule|
        UseCase::Financial::Recurrence::MaterializeRecurrenceRuleUseCase.new.call(rule: rule)
      end
    end

    def complete_installment_plans
      Financial::InstallmentPlan.status_active.find_each do |plan|
        next if plan.remaining_count > 0

        plan.update!(status: "completed")
      end
    end
  end
end
