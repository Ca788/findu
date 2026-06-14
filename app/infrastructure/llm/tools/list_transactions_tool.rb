# frozen_string_literal: true

module Llm
  module Tools
    class ListTransactionsTool < BaseTool
      description "Lista transações do usuário. Use quando ele pedir para ver, listar, encontrar, " \
                  "buscar, exibir, mostrar transações/gastos/receitas, ou para localizar uma transação " \
                  "antes de editar/excluir. Aceita filtros opcionais por tipo, categoria, período e descrição."

      param :transaction_type, type: "string", desc: "'expense' ou 'income'. Omita para listar ambos.", required: false
      param :category_id,      type: "string", desc: "UUID da categoria (use list_categories antes se necessário).", required: false
      param :from,             type: "string", desc: "Data inicial em ISO 8601 (YYYY-MM-DD).", required: false
      param :to,               type: "string", desc: "Data final em ISO 8601 (YYYY-MM-DD).", required: false
      param :description_like, type: "string", desc: "Busca textual parcial na descrição (ex.: 'mercado').", required: false
      param :limit,            type: "integer", desc: "Quantidade máxima (padrão 25, máx 100).", required: false

      def initialize(user:, lister: UseCase::Financial::Transaction::ListTransactionsUseCase.new)
        super()
        @user   = user
        @lister = lister
      end

      def execute(transaction_type: nil, category_id: nil, from: nil, to: nil, description_like: nil, limit: nil)
        safe_execute do
          transactions = @lister.call(
            user:             @user,
            transaction_type: whitelist(transaction_type, allowed: TRANSACTION_TYPES),
            category_id:      category_id.presence,
            from:             from.presence,
            to:               to.presence,
            description_like: description_like.presence,
            limit:            limit
          )

          { success: true, count: transactions.size, transactions: transactions.map { |t| serialize(t) } }
        end
      end

      private

      def serialize(transaction)
        {
          id:               transaction.id,
          amount:           transaction.amount.to_s,
          transaction_type: transaction.transaction_type,
          description:      transaction.description,
          occurred_at:      transaction.occurred_at&.iso8601,
          category_id:      transaction.category_id,
          category_name:    transaction.category&.name
        }
      end
    end
  end
end
