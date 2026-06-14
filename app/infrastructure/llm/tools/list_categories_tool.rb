# frozen_string_literal: true

module Llm
  module Tools
    class ListCategoriesTool < BaseTool
      description "Lista as categorias do usuário. Use quando ele pedir para ver/listar categorias, " \
                  "ou para descobrir o id de uma categoria antes de filtrar transações ou apagar/atualizar."

      param :name_like, type: "string", desc: "Busca textual parcial pelo nome (ex.: 'aliment').", required: false
      param :limit,     type: "integer", desc: "Quantidade máxima (padrão 100, máx 200).", required: false

      def initialize(user:, lister: UseCase::Financial::Category::ListCategoriesUseCase.new)
        super()
        @user   = user
        @lister = lister
      end

      def execute(name_like: nil, limit: nil)
        safe_execute do
          categories = @lister.call(user: @user, name_like: name_like.presence, limit: limit)
          {
            success:    true,
            count:      categories.size,
            categories: categories.map { |c| { id: c.id, name: c.name } }
          }
        end
      end
    end
  end
end
