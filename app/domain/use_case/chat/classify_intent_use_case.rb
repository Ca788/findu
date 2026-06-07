# frozen_string_literal: true

class UseCase::Chat::ClassifyIntentUseCase
  include Llm::ResponseParsing

  Result = Struct.new(:intent, :confidence, keyword_init: true)

  FALLBACK_INTENT = "unknown"
  FALLBACK_PAYLOAD = { "intent" => FALLBACK_INTENT, "confidence" => 0.0 }.freeze

  # @param [Array<String>]
  # @param [Llm::Prompts::ChatIntentPromptBuilder]
  def initialize(models: Llm::Models.chain("CHAT_INTENT_MODEL"),
                 prompt_builder: Llm::Prompts::ChatIntentPromptBuilder.new)
    @models         = models
    @prompt_builder = prompt_builder
  end

  # @param [String]
  # @return [Result]
  def call(text:)
    return Result.new(intent: FALLBACK_INTENT, confidence: 0.0) if text.blank?

    data = llm_extract(
      text:           text,
      schema:         Llm::Schemas::ChatIntentSchema,
      models:         @models,
      prompt_builder: @prompt_builder,
      fallback:       FALLBACK_PAYLOAD
    )

    intent = data["intent"].to_s
    intent = FALLBACK_INTENT unless Llm::Schemas::ChatIntentSchema::INTENTS.include?(intent)

    Result.new(intent: intent, confidence: data["confidence"].to_f)
  end
end
