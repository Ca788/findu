# frozen_string_literal: true

class UseCase::Messaging::ExtractTransactionFromMessageUseCase
  include Llm::ResponseParsing

  Result = Struct.new(:amount, :transaction_type, :description, :occurred_at, :category, :confidence, keyword_init: true)

  DEFAULT_MODEL = "gemini-2.5-flash"

  # @param [String]
  # @param [Llm::Prompts::TransactionPromptBuilder]
  def initialize(model: ENV.fetch("MESSAGING_LLM_MODEL", DEFAULT_MODEL),
                 prompt_builder: Llm::Prompts::TransactionPromptBuilder.new)
    @model          = model
    @prompt_builder = prompt_builder
  end

  # @param [String, nil]
  # @param [#body, nil]
  # @return [Result]
  def call(text: nil, message: nil)
    raw = text || message&.body
    raise ArgumentError, "text or message is required" if raw.blank?

    data = llm_extract(
      text:           raw,
      schema:         Llm::Schemas::TransactionSchema,
      model:          @model,
      prompt_builder: @prompt_builder
    )

    Result.new(
      amount:           parse_decimal(data["amount"]),
      transaction_type: parse_transaction_type(data["transaction_type"]),
      description:      data["description"],
      occurred_at:      parse_time(data["occurred_at"]),
      category:         data["category"].presence,
      confidence:       data["confidence"].to_f
    )
  end
end
