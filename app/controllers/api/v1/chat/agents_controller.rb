# frozen_string_literal: true

module Api
  module V1
    module Chat
      class AgentsController < Api::BaseController
        def index
          render json: ApiResponseSerializer.render_data_array(
            Llm::Agents::Registry::ALL,
            serializer:      ::V1::Chat::AgentSerializer,
            serializer_view: :default
          ), status: :ok
        end
      end
    end
  end
end
