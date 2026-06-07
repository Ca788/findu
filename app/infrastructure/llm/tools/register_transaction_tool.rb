# frozen_string_literal: true

module Llm
  module Tools
    class RegisterTransactionTool < RubyLLM::Tool
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
        category = @category_finder.call(user: @user, name: (category_name || description).to_s.strip.presence)
        type     = %w[expense income].include?(transaction_type.to_s) ? transaction_type.to_s : "expense"

        transaction = @creator.call(
          user:             @user,
          amount:           amount,
          transaction_type: type,
          description:      description,
          occurred_at:      parsed_time(occurred_at) || Time.current,
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
      rescue StandardError => e
        { success: false, error: e.message }
      end

      private

      def parsed_time(value)
        return nil if value.blank?

        Time.zone.parse(value.to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
