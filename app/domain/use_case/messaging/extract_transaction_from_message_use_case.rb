# frozen_string_literal: true

class UseCase::Messaging::ExtractTransactionFromMessageUseCase
  include Llm::ResponseParsing
  Result = Struct.new(:amount, :transaction_type, :description, :occurred_at, :confidence, keyword_init: true)

  DEFAULT_MODEL = "gemini-2.5-flash"

  # @param [String] model
  # @param [Llm::Prompts::TransactionPromptBuilder]
  def initialize(model: ENV.fetch("MESSAGING_LLM_MODEL", DEFAULT_MODEL),
                 prompt_builder: Llm::Prompts::TransactionPromptBuilder.new)
    @model          = model
    @prompt_builder = prompt_builder
  end

  # @param [Messaging::Message]
  # @return [UseCase::Messaging::ExtractTransactionFromMessageUseCase::Result]
  def call(message:)
    chat = RubyLLM.chat(model: @model).with_schema(Llm::Schemas::TransactionSchema)
    response = chat.ask(@prompt_builder.call(text: message.body))
    parse(response)
  end

  private

  # @param [RubyLLM::Message]
  # @return [Result]
  def parse(response)
    data = parse_payload(response.content)
    Result.new(
      amount:           parse_decimal(data["amount"]),
      transaction_type: parse_transaction_type(data["transaction_type"]),
      description:      data["description"],
      occurred_at:      parse_time(data["occurred_at"]),
      confidence:       data["confidence"].to_f
    )
  end

  def parse_payload(content)
    return content if content.is_a?(Hash)

    JSON.parse(content.to_s)
  rescue JSON::ParserError
    { "confidence" => 0.0 }
  end
end
