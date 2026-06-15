# frozen_string_literal: true

class UseCase::Chat::SelectAgentUseCase
  Result = Struct.new(:agent, :intent, :confidence, keyword_init: true)

  MIN_CONFIDENCE = 0.5

  # @param [UseCase::Chat::ClassifyIntentUseCase]
  def initialize(classifier: UseCase::Chat::ClassifyIntentUseCase.new)
    @classifier = classifier
  end

  # @param [String, nil]
  # @param [Symbol, String, nil]
  # @return [Result]
  def call(text:, forced_agent: nil)
    if forced_agent
      agent = Llm::Agents::Registry.find(forced_agent) || Llm::Agents::Registry::DEFAULT
      return Result.new(agent: agent, intent: nil, confidence: nil)
    end

    if text.blank?
      return Result.new(agent: Llm::Agents::Registry::DEFAULT, intent: "unknown", confidence: 0.0)
    end

    classification = @classifier.call(text: text)
    agent = if classification.confidence >= MIN_CONFIDENCE
              Llm::Agents::Registry.for_intent(classification.intent)
            else
              Llm::Agents::Registry::DEFAULT
            end

    Result.new(agent: agent, intent: classification.intent, confidence: classification.confidence)
  rescue StandardError => e
    Rails.logger.warn("[SelectAgentUseCase] falling back to default: #{e.class}: #{e.message}")
    Result.new(agent: Llm::Agents::Registry::DEFAULT, intent: "unknown", confidence: 0.0)
  end
end
