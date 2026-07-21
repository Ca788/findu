# frozen_string_literal: true

module Api
  module V1
    module Chat
      class ModelsController < Api::BaseController
        def index
          render json: {
            data: Llm::Models.catalog.map do |model|
              {
                id:          model[:id],
                name:        model[:name],
                description: model[:description]
              }
            end
          }, status: :ok
        end
      end
    end
  end
end
