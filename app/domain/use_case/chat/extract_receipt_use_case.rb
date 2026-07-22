# frozen_string_literal: true

class UseCase::Chat::ExtractReceiptUseCase
  include Llm::ResponseParsing

  Receipt = Struct.new(
    :amount, :occurred_at, :description, :transaction_type, :confidence, :raw_text,
    :is_installment, :total_installments, :monthly_amount, :total_amount,
    keyword_init: true
  )

  FALLBACK_PAYLOAD = { "confidence" => 0.0, "transaction_type" => "expense", "is_installment" => false }.freeze

  def initialize(models: Llm::Models.chain("CHAT_RECEIPT_MODEL"),
                 prompt_builder: Llm::Prompts::ReceiptPromptBuilder.new,
                 schema: Llm::Schemas::ReceiptSchema)
    @models         = models
    @prompt_builder = prompt_builder
    @schema         = schema
  end

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

    response = Llm::ModelFallback.with_fallback(@models) do |model|
      Llm::GeminiChat.for(model).with_schema(@schema).ask(@prompt_builder.call, with: path)
    end
    build_receipt(parse_payload(response.content, fallback: FALLBACK_PAYLOAD))
  rescue StandardError => e
    Rails.logger.warn("[ExtractReceiptUseCase] failed for #{attachment.filename}: #{e.class}: #{e.message}")
    nil
  end

  def build_receipt(data)
    is_installment = ActiveModel::Type::Boolean.new.cast(data["is_installment"])
    Receipt.new(
      amount:             parse_decimal(data["amount"]),
      occurred_at:        parse_time(data["occurred_at"]),
      description:        data["description"],
      transaction_type:   parse_transaction_type(data["transaction_type"]),
      confidence:         data["confidence"].to_f,
      raw_text:           data["raw_text"].to_s,
      is_installment:     is_installment,
      total_installments: data["total_installments"].presence&.to_i,
      monthly_amount:     parse_decimal(data["monthly_amount"]),
      total_amount:       parse_decimal(data["total_amount"])
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
