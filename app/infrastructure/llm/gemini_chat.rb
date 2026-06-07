# frozen_string_literal: true

module Llm
  # Builds a RubyLLM chat for a Gemini model id while bypassing the gem's
  # bundled model registry. That registry predates the gemini-3.x ids we use,
  # so without assume_model_exists it raises ModelNotFoundError before ever
  # reaching the API. Provider is pinned to :gemini because every model in our
  # chains is Gemini.
  module GeminiChat
    PROVIDER = :gemini

    module_function

    # @param [String] model
    # @return [RubyLLM::Chat]
    def for(model)
      RubyLLM.chat(model: model, provider: PROVIDER, assume_model_exists: true)
    end
  end
end
