# frozen_string_literal: true

module Llm
  module Tools
    class RegisterCategoryTool < RubyLLM::Tool
      description "Cria (ou recupera, se já existir) uma categoria do usuário. " \
                  "Use quando o usuário pedir explicitamente para criar uma categoria, sem valor associado."

      param :name, type: "string", desc: "Nome da categoria (ex.: 'Alimentação', 'Transporte')."

      def initialize(user:, finder: UseCase::Financial::Category::FindOrCreateByNameUseCase.new)
        super()
        @user   = user
        @finder = finder
      end

      def execute(name:)
        category = @finder.call(user: @user, name: name.to_s.strip)
        return { success: false, error: "Nome de categoria vazio." } if category.nil?

        { success: true, category_id: category.id, name: category.name }
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end
  end
end
