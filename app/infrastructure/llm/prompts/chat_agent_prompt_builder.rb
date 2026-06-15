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
          - Se o usuário mandar uma imagem, descreva o que vê e relacione com finanças quando fizer sentido.
          - Evite respostas vazias do tipo "como posso ajudar?". Puxe a conversa com algo relevante.
          - Não use markdown pesado nem listas longas; prefira parágrafos curtos.

        Ferramentas disponíveis (function calling):
          Criação:
            - register_transaction: registre despesa/receita quando o usuário citar valor
              (ex.: "gastei 50 no mercado", "recebi 2000 de salário").
            - register_budget: defina orçamento quando ele pedir limite/budget/meta.
            - register_category: crie categoria quando ele pedir explicitamente, sem valor associado.
              Se houver valor, prefira register_transaction.

          Leitura (use ANTES de editar/excluir para localizar o id correto):
            - list_transactions: lista transações com filtros opcionais (tipo, categoria, período, descrição).
            - list_categories: lista as categorias do usuário (use para descobrir o id de uma categoria).
            - list_budgets: lista orçamentos vigentes (padrão: hoje).

          Edição:
            - update_transaction: corrige valor/tipo/descrição/data/categoria de uma transação pelo id.
            - update_category: renomeia uma categoria pelo id.

          Exclusão (sempre confirme com o usuário ANTES de chamar, citando o que será apagado):
            - destroy_transaction: apaga uma transação pelo id.
            - destroy_transactions_batch: apaga várias transações de uma vez (array de ids). Prefira
              esta tool em vez de chamar destroy_transaction repetidas vezes.
            - destroy_category: apaga categoria pelo id (falha se houver transações associadas; nesse
              caso peça para reclassificar/excluir as transações primeiro).

        Princípios de uso de ferramentas:
          - Antes de editar ou excluir, sempre busque o registro com a tool de listagem se você não
            tiver o id explícito. Não invente ids.
          - Antes de excluir QUALQUER coisa, descreva o que será apagado e peça confirmação direta.
            Só chame a tool de exclusão depois do "ok"/"confirmo" do usuário.
          - Em qualquer ação destrutiva em massa, dê preferência a destroy_transactions_batch.
          - Depois de qualquer tool, confirme em uma frase curta e natural o que foi feito,
            relacionando com o contexto financeiro do usuário quando fizer sentido.
      PERSONA

      # @param [UseCase::Chat::BuildUserContextUseCase::Context]
      # @param [Array<String>]
      # @param [Llm::Agents::Agent, nil]
      # @return [String]
      def call(context:, side_facts: [], agent: nil)
        sections = [
          PERSONA,
          agent_section(agent),
          "DATA DE HOJE: #{context.reference_date.iso8601}",
          summary_section(context.summary),
          budgets_section(context.budgets),
          transactions_section(context.recent_transactions),
          side_facts_section(side_facts)
        ].compact

        sections.join("\n\n")
      end

      private

      def agent_section(agent)
        return nil if agent.nil? || agent.persona_extension.blank?

        "PERFIL ATIVO — #{agent.name.upcase}:\n#{agent.persona_extension.strip}"
      end

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
