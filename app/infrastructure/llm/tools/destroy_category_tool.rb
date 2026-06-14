# frozen_string_literal: true

module Llm
  module Tools
    class DestroyCategoryTool < BaseTool
      description "Exclui uma categoria do usuário pelo id. Falha se houver transações associadas — " \
                  "neste caso, peça ao usuário para reclassificar as transações primeiro."

      param :id, type: "string", desc: "UUID da categoria."

      def initialize(user:, destroyer: UseCase::Financial::Category::DestroyCategoryUseCase.new)
        super()
        @user      = user
        @destroyer = destroyer
      end

      def execute(id:)
        safe_execute do
          category = @destroyer.call(user: @user, id: id.to_s)
          { success: true, category_id: category.id, name: category.name }
        end
      end
    end
  end
end
