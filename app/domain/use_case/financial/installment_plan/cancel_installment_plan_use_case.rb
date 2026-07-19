# frozen_string_literal: true

class UseCase::Financial::InstallmentPlan::CancelInstallmentPlanUseCase
  # Cancela o plano e remove as parcelas futuras pendentes.
  # Parcelas passadas ou já pagas ficam preservadas no histórico.
  #
  # @param [User]
  # @param [String] plan id
  # @return [Financial::InstallmentPlan]
  def call(user:, id:)
    plan = user.installment_plans.find(id)

    ApplicationRecord.transaction do
      plan.update!(status: "canceled", canceled_at: Time.current)

      plan.transactions
          .where(status: "pending")
          .where("competency_month >= ?", Date.current.beginning_of_month)
          .destroy_all
    end

    plan
  end
end
