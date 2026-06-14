# frozen_string_literal: true

module Llm
  module Tools
    class UpdateTransactionTool < BaseTool
      description "Atualiza uma transação existente do usuário. Use quando o usuário pedir para " \
                  "corrigir/alterar valor, descrição, tipo, data ou categoria. " \
                  "Localize o id antes via list_transactions se necessário. " \
                  "Apenas os campos enviados são alterados."

      param :id,               type: "string",  desc: "UUID da transação."
      param :amount,           type: "number",  desc: "Novo valor em reais.", required: false
      param :transaction_type, type: "string",  desc: "'expense' ou 'income'.", required: false
      param :description,      type: "string",  desc: "Nova descrição.", required: false
      param :occurred_at,      type: "string",  desc: "Nova data ISO 8601 (YYYY-MM-DD).", required: false
      param :category_id,      type: "string",  desc: "Novo UUID de categoria. Use list_categories para descobrir.", required: false
      param :category_name,    type: "string",  desc: "Alternativa ao category_id: nome da categoria (será criada se não existir).", required: false

      def initialize(user:,
                     updater: UseCase::Financial::Transaction::UpdateTransactionUseCase.new,
                     category_finder: UseCase::Financial::Category::FindOrCreateByNameUseCase.new)
        super()
        @user            = user
        @updater         = updater
        @category_finder = category_finder
      end

      def execute(id:, amount: nil, transaction_type: nil, description: nil, occurred_at: nil, category_id: nil, category_name: nil)
        safe_execute do
          transaction = @updater.call(
            user:             @user,
            id:               id.to_s,
            amount:           amount,
            transaction_type: whitelist(transaction_type, allowed: TRANSACTION_TYPES),
            description:      description,
            occurred_at:      parse_time(occurred_at),
            category_id:      resolve_category_id(category_id: category_id, category_name: category_name)
          )

          {
            success:          true,
            transaction_id:   transaction.id,
            amount:           transaction.amount.to_s,
            transaction_type: transaction.transaction_type,
            description:      transaction.description,
            occurred_at:      transaction.occurred_at&.iso8601,
            category_id:      transaction.category_id
          }
        end
      end

      private

      def resolve_category_id(category_id:, category_name:)
        return category_id if category_id.present?
        return nil         if category_name.blank?

        @category_finder.call(user: @user, name: category_name.to_s.strip)&.id
      end
    end
  end
end
