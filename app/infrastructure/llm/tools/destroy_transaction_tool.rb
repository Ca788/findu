# frozen_string_literal: true

module Llm
  module Tools
    class DestroyTransactionTool < BaseTool
      description "Exclui uma transação específica do usuário pelo id. " \
                  "Use somente após confirmar com o usuário o que será apagado. " \
                  "Para localizar o id, use list_transactions antes."

      param :id, type: "string", desc: "UUID da transação a ser excluída."

      def initialize(user:, destroyer: UseCase::Financial::Transaction::DestroyTransactionUseCase.new)
        super()
        @user      = user
        @destroyer = destroyer
      end

      def execute(id:)
        safe_execute do
          transaction = @destroyer.call(user: @user, id: id.to_s)
          {
            success:        true,
            transaction_id: transaction.id,
            amount:         transaction.amount.to_s,
            description:    transaction.description
          }
        end
      end
    end
  end
end
