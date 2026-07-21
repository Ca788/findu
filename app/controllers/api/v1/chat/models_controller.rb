# frozen_string_literal: true

module Api
  module V1
    module Chat
      class ModelsController < Api::BaseController
        def index
          render json: {
            data: Llm::Models.available("CHAT_AGENT_MODEL")
          }, status: :ok
        end
      end
    end
  end
end
