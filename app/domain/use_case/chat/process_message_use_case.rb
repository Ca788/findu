# frozen_string_literal: true

class UseCase::Chat::ProcessMessageUseCase
  RECEIPT_CONFIDENCE_THRESHOLD = 0.6

  SideEffect = Struct.new(:payload, :fact, keyword_init: true)

  # @param [UseCase::Chat::TranscribeMessageUseCase]
  # @param [UseCase::Chat::ExtractReceiptUseCase]
  # @param [UseCase::Financial::Transaction::CreateTransactionUseCase]
  # @param [UseCase::Financial::Category::FindOrCreateByNameUseCase]
  # @param [UseCase::Chat::AnswerConversationallyUseCase]
  # @param [UseCase::Chat::SelectAgentUseCase]
  def initialize(transcriber: UseCase::Chat::TranscribeMessageUseCase.new,
                 receipt_extractor: UseCase::Chat::ExtractReceiptUseCase.new,
                 transaction_creator: UseCase::Financial::Transaction::CreateTransactionUseCase.new,
                 category_finder: UseCase::Financial::Category::FindOrCreateByNameUseCase.new,
                 answerer: UseCase::Chat::AnswerConversationallyUseCase.new,
                 agent_selector: UseCase::Chat::SelectAgentUseCase.new)
    @transcriber         = transcriber
    @receipt_extractor   = receipt_extractor
    @transaction_creator = transaction_creator
    @category_finder     = category_finder
    @answerer            = answerer
    @agent_selector      = agent_selector
  end

  # @param [Chat::Message] message
  # @return [Chat::Message] assistant reply
  def call(message:)
    message.update!(status: "processing")
    message.conversation.broadcast_message!(message)

    transcription_metadata = transcribe_if_audio(message)
    receipt_side_effects   = run_receipt_side_effects(message)

    payload = merge_payloads(receipt_side_effects).merge(
      transcription: transcription_metadata
    ).compact

    finalize_user_message(message, payload: payload)

    selection = @agent_selector.call(text: message.body)
    @answerer.call(
      user_message: message,
      side_facts:   receipt_side_effects.map(&:fact),
      agent:        selection.agent
    )
  rescue StandardError => e
    message.update!(
      status: "failed",
      error:  { class: e.class.name, message: e.message }
    )
    message.conversation.broadcast_message!(message)
    raise
  end

  private

  def transcribe_if_audio(message)
    return nil unless message.kind_audio?

    transcription = @transcriber.call(message: message)
    {
      confidence: transcription.confidence,
      provider:   transcription.metadata && transcription.metadata[:provider],
      model:      transcription.metadata && transcription.metadata[:model]
    }.compact
  end

  def run_receipt_side_effects(message)
    return [] unless message.image_attachments.any?

    receipts = @receipt_extractor.call(message: message)
    receipts.filter_map do |receipt|
      next nil if receipt.amount.blank? || receipt.confidence.to_f < RECEIPT_CONFIDENCE_THRESHOLD

      category    = @category_finder.call(user: message.user, name: receipt.description.presence)
      transaction = @transaction_creator.call(
        user:             message.user,
        amount:           receipt.amount,
        transaction_type: receipt.transaction_type,
        description:      receipt.description,
        occurred_at:      receipt.occurred_at || Time.current,
        category_id:      category&.id
      )

      type = transaction.expense? ? "despesa" : "receita"
      fact = "registrei #{type} de #{Formatters::Brl.call(transaction.amount)} a partir do recibo enviado" \
             "#{transaction.description.present? ? " (#{transaction.description})" : ''}" \
             "#{category ? " na categoria #{category.name}" : ''}."

      SideEffect.new(
        payload: {
          receipt_transaction_id: transaction.id,
          receipt_category_id:    category&.id,
          receipt_confidence:     receipt.confidence
        }.compact,
        fact: fact
      )
    end
  end

  def merge_payloads(side_effects)
    side_effects.each_with_object({}) { |effect, acc| acc.merge!(effect.payload) }
  end

  def finalize_user_message(message, payload:)
    message.update!(status: "completed", payload: payload)
    message.conversation.broadcast_message!(message)
  end
end
