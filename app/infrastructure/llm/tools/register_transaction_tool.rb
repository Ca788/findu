# frozen_string_literal: true

module Llm
  module Tools
    class RegisterTransactionTool < BaseTool
      description "Registra uma despesa (expense) ou receita (income) do usuário. " \
                  "Use sempre que ele mencionar um gasto, pagamento, compra, recebimento ou similar com valor."

      param :amount, type: "number", desc: "Valor em reais (decimal, sem símbolo de moeda)."
      param :transaction_type, type: "string", desc: "'expense' para gastos/pagamentos, 'income' para receitas/recebimentos."
      param :description, type: "string", desc: "Descrição curta da transação (ex.: 'mercado', 'salário Pix Maria').", required: false
      param :category_name, type: "string", desc: "Nome da categoria sugerida pelo contexto da mensagem.", required: false
      param :occurred_at, type: "string", desc: "Data da transação em ISO 8601 (YYYY-MM-DD). Se ausente, será hoje.", required: false

      def initialize(user:,
                     creator: UseCase::Financial::Transaction::CreateTransactionUseCase.new,
                     category_finder: UseCase::Financial::Category::FindOrCreateByNameUseCase.new)
        super()
        @user            = user
        @creator         = creator
        @category_finder = category_finder
      end

      def execute(amount:, transaction_type:, description: nil, category_name: nil, occurred_at: nil)
        safe_execute do
          category = @category_finder.call(user: @user, name: (category_name || description).to_s.strip.presence)
          type     = whitelist(transaction_type, allowed: TRANSACTION_TYPES, default: "expense")

          transaction = @creator.call(
            user:             @user,
            amount:           amount,
            transaction_type: type,
            description:      description,
            occurred_at:      parse_time(occurred_at) || Time.current,
            category_id:      category&.id
          )

          {
            success:        true,
            transaction_id: transaction.id,
            amount:         transaction.amount.to_s,
            type:           type,
            description:    transaction.description,
            category:       category&.name
          }
        end
      end
    end
  end
end
