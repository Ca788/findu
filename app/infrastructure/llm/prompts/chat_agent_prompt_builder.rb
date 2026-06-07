# frozen_string_literal: true

module Llm
  module Prompts
    class ChatAgentPromptBuilder
      PERSONA = <<~PERSONA.freeze
        Você é o assistente financeiro pessoal do usuário no FindU.
        Sua missão: conversar como um amigo sincero que entende de dinheiro. Você observa padrões, dá
        feedback genuíno (sem bajulação), e ajuda a tomar decisões.

        Princípios:
          - Fale em português brasileiro, com naturalidade. Tom honesto, gentil, prático.
          - Use os dados financeiros fornecidos abaixo como verdade — não invente números.
          - Se faltar informação, peça (curto e específico). Se não souber, diga.
          - Não despeje relatórios completos a menos que peçam; resuma e destaque o que importa.
          - Quando o usuário registrar transações, orçamentos ou categorias, comente brevemente o que
            isso significa no contexto dele (ex.: "isso já passou metade do orçamento de alimentação").
          - Se o usuário mandar uma imagem, descreva o que vê e relacione com finanças quando fizer sentido.
          - Evite respostas vazias do tipo "como posso ajudar?". Puxe a conversa com algo relevante.
          - Não use markdown pesado nem listas longas; prefira parágrafos curtos.
      PERSONA

      # @param [UseCase::Chat::BuildUserContextUseCase::Context] context
      # @param [Array<String>] side_facts
      # @return [String]
      def call(context:, side_facts: [])
        sections = [
          PERSONA,
          "DATA DE HOJE: #{context.reference_date.iso8601}",
          summary_section(context.summary),
          budgets_section(context.budgets),
          transactions_section(context.recent_transactions),
          side_facts_section(side_facts)
        ].compact

        sections.join("\n\n")
      end

      private

      def summary_section(summary)
        income  = summary.by_type["income"]  || 0
        expense = summary.by_type["expense"] || 0
        net     = income - expense

        <<~SECTION.strip
          RESUMO DO PERÍODO (#{summary.from.strftime('%d/%m')} a #{summary.to.strftime('%d/%m')}):
            - Receitas: #{Formatters::Brl.call(income)}
            - Despesas: #{Formatters::Brl.call(expense)}
            - Saldo:    #{Formatters::Brl.call(net)}
            - Transações: #{summary.transaction_count}
        SECTION
      end

      def budgets_section(budgets)
        return "ORÇAMENTOS ATIVOS: nenhum orçamento vigente hoje." if budgets.blank?

        lines = budgets.map do |budget|
          "- #{budget.period_type.capitalize} (#{budget.period_start.strftime('%d/%m')}–#{budget.period_end.strftime('%d/%m')}): " \
            "#{Formatters::Brl.call(budget.spent_amount)} de #{Formatters::Brl.call(budget.limit_amount)} (#{budget.usage_percent}%), resta #{Formatters::Brl.call(budget.remaining)}"
        end

        "ORÇAMENTOS ATIVOS:\n#{lines.join("\n")}"
      end

      def transactions_section(transactions)
        return "ÚLTIMAS TRANSAÇÕES: nenhuma transação registrada ainda." if transactions.blank?

        lines = transactions.map do |t|
          type     = t.expense? ? "despesa" : "receita"
          category = t.category&.name || "sem categoria"
          desc     = t.description.present? ? " — #{t.description}" : ""
          "- #{t.occurred_at.strftime('%d/%m')} · #{type} de #{Formatters::Brl.call(t.amount)} [#{category}]#{desc}"
        end

        "ÚLTIMAS TRANSAÇÕES (até #{transactions.size}):\n#{lines.join("\n")}"
      end

      def side_facts_section(side_facts)
        return nil if side_facts.blank?

        "FATOS RECENTES (acabaram de acontecer):\n#{side_facts.map { |f| "- #{f}" }.join("\n")}"
      end
    end
  end
end
