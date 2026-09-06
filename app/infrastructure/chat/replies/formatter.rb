# frozen_string_literal: true

module Chat
  module Replies
    module Formatter
      module_function

      FALLBACK = 'Não entendi. Tente algo como: "gastei 50 no mercado", "orçamento mensal de 2000" ou "quanto posso gastar?".'

      # @return [String]
      def fallback
        FALLBACK
      end

      # @param [Financial::Transaction]
      # @return [String]
      def transaction(transaction)
        type        = transaction.expense? ? "Despesa" : "Receita"
        value       = Formatters::Brl.call(transaction.amount)
        description = transaction.description.present? ? " - #{transaction.description}" : ""
        category    = transaction.category ? " [#{transaction.category.name}]" : ""
        "#{type} registrada: #{value}#{description}#{category}"
      end

      # @param [Financial::Budget]
      # @return [String]
      def budget(budget)
        "Orçamento criado: #{budget.period_type} de #{Formatters::Brl.call(budget.limit_amount)} " \
          "(#{budget.period_start.strftime('%d/%m')} a #{budget.period_end.strftime('%d/%m')})."
      end

      # @param [Financial::Receipt]
      # @return [String]
      def receipt(receipt)
        period   = "#{receipt.period_start.strftime('%m/%Y')} a #{receipt.period_end.strftime('%m/%Y')}"
        category = receipt.payer_name.present? ? " da categoria #{receipt.payer_name}" : ""

        "Segue o comprovante#{category} referente a #{period}. " \
          "Total pago: #{Formatters::Brl.call(receipt.total_amount)}."
      end

      # @param [Financial::InstallmentPlan]
      # @return [String]
      def installment_plan(plan)
        total       = Formatters::Brl.call(plan.total_amount_derived)
        monthly     = Formatters::Brl.call(plan.monthly_amount)
        description = plan.description.present? ? " (#{plan.description})" : ""
        "Compra parcelada registrada: #{total} em #{plan.total_installments}x de #{monthly}#{description}."
      end
    end
  end
end
