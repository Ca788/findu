# frozen_string_literal: true

module Llm
  module Tools
    class RegisterInstallmentPlanTool < BaseTool
      description "Registra um parcelamento (compra em N vezes). " \
                  "Use SOMENTE após o usuário confirmar os dados do parcelamento. " \
                  "Não use register_transaction para compras parceladas."

      param :monthly_amount, type: "number", desc: "Valor de cada parcela em reais."
      param :total_installments, type: "number", desc: "Quantidade de parcelas (inteiro >= 2)."
      param :description, type: "string", desc: "Descrição do que foi comprado.", required: false
      param :total_amount, type: "number", desc: "Valor total financiado, se conhecido.", required: false
      param :first_competency, type: "string", desc: "Mês da 1ª parcela YYYY-MM-DD (dia 1). Se ausente, mês atual.", required: false
      param :category_name, type: "string", desc: "Categoria sugerida.", required: false

      def initialize(user:,
                     creator: UseCase::Financial::InstallmentPlan::CreateInstallmentPlanUseCase.new,
                     category_finder: UseCase::Financial::Category::FindOrCreateByNameUseCase.new)
        super()
        @user            = user
        @creator         = creator
        @category_finder = category_finder
      end

      def execute(monthly_amount:, total_installments:, description: nil, total_amount: nil,
                  first_competency: nil, category_name: nil)
        safe_execute do
          count = total_installments.to_i
          raise ArgumentError, "total_installments deve ser >= 2" if count < 2

          category = @category_finder.call(
            user: @user,
            name: (category_name || description).to_s.strip.presence
          )
          first = parse_date(first_competency)&.beginning_of_month || Date.current.beginning_of_month

          plan = @creator.call(
            user: @user,
            attributes: {
              description:        description,
              transaction_type:   "expense",
              total_installments: count,
              monthly_amount:     monthly_amount,
              total_amount:       total_amount,
              first_competency:   first,
              category_id:        category&.id
            }.compact
          )

          {
            success:            true,
            installment_plan_id: plan.id,
            monthly_amount:     plan.monthly_amount.to_s,
            total_installments: plan.total_installments,
            total_amount:       plan.total_amount.to_s,
            description:        plan.description,
            category:           category&.name
          }
        end
      end
    end
  end
end
