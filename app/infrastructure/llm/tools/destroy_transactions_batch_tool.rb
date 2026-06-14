# frozen_string_literal: true

module Llm
  module Tools
    class DestroyTransactionsBatchTool < BaseTool
      description "Exclui várias transações do usuário em lote, dado um array de ids. " \
                  "Use depois de confirmar com o usuário. Para múltiplas, prefira esta tool em vez " \
                  "de chamar destroy_transaction várias vezes."

      param :ids, type: "array", desc: "Array de UUIDs das transações.", required: true

      def initialize(user:, destroyer: UseCase::Financial::Transaction::DestroyTransactionsBatchUseCase.new)
        super()
        @user      = user
        @destroyer = destroyer
      end

      def execute(ids:)
        safe_execute do
          list = Array(ids).map(&:to_s)
          next { success: false, error: "ids vazio" } if list.empty?

          result = @destroyer.call(user: @user, ids: list)
          {
            success:         true,
            destroyed_ids:   result.destroyed_ids,
            destroyed_count: result.destroyed_ids.size,
            missing_ids:     result.missing_ids
          }
        end
      end
    end
  end
end
