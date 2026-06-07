# frozen_string_literal: true

class UseCase::Chat::ExtractReceiptUseCase
  include Llm::ResponseParsing

  Receipt = Struct.new(
    :amount, :occurred_at, :description, :transaction_type, :confidence, :raw_text,
    keyword_init: true
  )

  DEFAULT_MODEL = "gemini-2.5-flash"
  FALLBACK_PAYLOAD = { "confidence" => 0.0, "transaction_type" => "expense" }.freeze

  def initialize(model: ENV.fetch("CHAT_RECEIPT_MODEL", DEFAULT_MODEL),
                 prompt_builder: Llm::Prompts::ReceiptPromptBuilder.new,
                 schema: Llm::Schemas::ReceiptSchema)
    @model          = model
    @prompt_builder = prompt_builder
    @schema         = schema
  end

  # Tries to extract a receipt from each image attachment of the message.
  # Returns one Receipt per image (failed extractions come with confidence 0).
  #
  # @param [Chat::Message] message
  # @return [Array<Receipt>]
  def call(message:)
    images = message.image_attachments
    return [] if images.empty?

    images.filter_map { |att| extract_one(att) }
  end

  private

  def extract_one(attachment)
    path = local_path_for(attachment)
    return nil if path.nil?

    chat = RubyLLM.chat(model: @model).with_schema(@schema)
    response = chat.ask(@prompt_builder.call, with: path)
    build_receipt(parse_payload(response.content, fallback: FALLBACK_PAYLOAD))
  rescue StandardError => e
    Rails.logger.warn("[ExtractReceiptUseCase] failed for #{attachment.filename}: #{e.class}: #{e.message}")
    nil
  end

  def build_receipt(data)
    Receipt.new(
      amount:           parse_decimal(data["amount"]),
      occurred_at:      parse_time(data["occurred_at"]),
      description:      data["description"],
      transaction_type: parse_transaction_type(data["transaction_type"]),
      confidence:       data["confidence"].to_f,
      raw_text:         data["raw_text"].to_s
    )
  end

  def local_path_for(attachment)
    service = ActiveStorage::Blob.service
    if service.respond_to?(:path_for)
      path = service.path_for(attachment.key)
      return path if File.exist?(path)
    end

    tempfile = Tempfile.new(["receipt", File.extname(attachment.filename.to_s)], binmode: true)
    attachment.download { |chunk| tempfile.write(chunk) }
    tempfile.flush
    tempfile.path
  end
end
