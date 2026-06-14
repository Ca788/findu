# frozen_string_literal: true

module Llm
  module Tools
    class UpdateCategoryTool < BaseTool
      description "Renomeia uma categoria existente do usuário."

      param :id,   type: "string", desc: "UUID da categoria."
      param :name, type: "string", desc: "Novo nome da categoria."

      def initialize(user:, updater: UseCase::Financial::Category::UpdateCategoryUseCase.new)
        super()
        @user    = user
        @updater = updater
      end

      def execute(id:, name:)
        safe_execute do
          category = @updater.call(user: @user, id: id.to_s, attributes: { name: name.to_s.strip })
          { success: true, category_id: category.id, name: category.name }
        end
      end
    end
  end
end
