# frozen_string_literal: true

class UseCase::Chat::ProcessMessageUseCase
  TRANSACTION_CONFIDENCE_THRESHOLD = 0.5
  INTENT_CONFIDENCE_THRESHOLD      = 0.4
  RECEIPT_CONFIDENCE_THRESHOLD     = 0.6

  SideEffect = Struct.new(:payload, :fact, keyword_init: true)

  # @param [UseCase::Chat::ClassifyIntentUseCase] classifier
  # @param [UseCase::Chat::TranscribeMessageUseCase] transcriber
  # @param [UseCase::Messaging::ExtractTransactionFromMessageUseCase] transaction_extractor
  # @param [UseCase::Chat::ExtractBudgetUseCase] budget_extractor
  # @param [UseCase::Chat::ExtractCategoryUseCase] category_extractor
  # @param [UseCase::Chat::ExtractInstallmentUseCase] installment_extractor
  # @param [UseCase::Financial::Transaction::CreateTransactionUseCase] transaction_creator
  # @param [UseCase::Financial::Category::FindOrCreateByNameUseCase] category_finder
  # @param [UseCase::Chat::AnswerConversationallyUseCase] answerer
  def initialize(classifier: UseCase::Chat::ClassifyIntentUseCase.new,
                 transcriber: UseCase::Chat::TranscribeMessageUseCase.new,
                 transaction_extractor: UseCase::Messaging::ExtractTransactionFromMessageUseCase.new,
                 budget_extractor: UseCase::Chat::ExtractBudgetUseCase.new,
                 category_extractor: UseCase::Chat::ExtractCategoryUseCase.new,
                 installment_extractor: UseCase::Chat::ExtractInstallmentUseCase.new,
                 receipt_extractor: UseCase::Chat::ExtractReceiptUseCase.new,
                 transaction_creator: UseCase::Financial::Transaction::CreateTransactionUseCase.new,
                 category_finder: UseCase::Financial::Category::FindOrCreateByNameUseCase.new,
                 answerer: UseCase::Chat::AnswerConversationallyUseCase.new)
    @classifier            = classifier
    @transcriber           = transcriber
    @transaction_extractor = transaction_extractor
    @budget_extractor      = budget_extractor
    @category_extractor    = category_extractor
    @installment_extractor = installment_extractor
    @receipt_extractor     = receipt_extractor
    @transaction_creator   = transaction_creator
    @category_finder       = category_finder
    @answerer              = answerer
  end

  # @param [Chat::Message] message
  # @return [Chat::Message] assistant reply
  def call(message:)
    message.update!(status: "processing")
    message.conversation.broadcast_message!(message)

    transcription_metadata = transcribe_if_audio(message)
    classification         = @classifier.call(text: message.body)
    effective_intent       = effective_intent_from(classification)

    side_effects = []
    side_effects << run_side_effect(user: message.user, intent: effective_intent, text: message.body)
    side_effects.concat(run_receipt_side_effects(message))
    side_effects.compact!

    payload = merge_side_effect_payloads(side_effects).merge(
      intent_confidence: classification.confidence,
      transcription:     transcription_metadata
    ).compact

    finalize_user_message(message, intent: effective_intent, payload: payload)

    @answerer.call(user_message: message, side_facts: side_effects.map(&:fact))
  rescue StandardError => e
    message.update!(
      status: "failed",
      error:  { class: e.class.name, message: e.message }
    )
    message.conversation.broadcast_message!(message)
    raise
  end

  private

  def effective_intent_from(classification)
    return "unknown" if classification.confidence.to_f < INTENT_CONFIDENCE_THRESHOLD

    classification.intent
  end

  def transcribe_if_audio(message)
    return nil unless message.kind_audio?

    transcription = @transcriber.call(message: message)
    {
      confidence: transcription.confidence,
      provider:   transcription.metadata && transcription.metadata[:provider],
      model:      transcription.metadata && transcription.metadata[:model]
    }.compact
  end

  def run_side_effect(user:, intent:, text:)
    handler = side_effect_dispatch[intent]
    return nil if handler.nil? || text.blank?

    handler.call(user: user, text: text)
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

  def merge_side_effect_payloads(side_effects)
    side_effects.each_with_object({}) { |effect, acc| acc.merge!(effect.payload) }
  end

  def side_effect_dispatch
    @side_effect_dispatch ||= {
      "create_transaction" => method(:side_effect_transaction),
      "create_budget"      => method(:side_effect_budget),
      "create_category"    => method(:side_effect_category),
      "create_installment" => method(:side_effect_installment)
    }
  end

  def side_effect_transaction(user:, text:)
    result = @transaction_extractor.call(text: text)
    return nil if result.amount.blank? || result.confidence.to_f < TRANSACTION_CONFIDENCE_THRESHOLD

    category    = @category_finder.call(user: user, name: result.category.presence || result.description.presence)
    transaction = @transaction_creator.call(
      user:             user,
      amount:           result.amount,
      transaction_type: result.transaction_type,
      description:      result.description,
      occurred_at:      result.occurred_at || Time.current,
      category_id:      category&.id
    )

    type = transaction.expense? ? "despesa" : "receita"
    fact = "registrei #{type} de #{Formatters::Brl.call(transaction.amount)}" \
           "#{transaction.description.present? ? " (#{transaction.description})" : ''}" \
           "#{category ? " na categoria #{category.name}" : ''}."

    SideEffect.new(
      payload: { transaction_id: transaction.id, category_id: category&.id, confidence: result.confidence.to_f }.compact,
      fact:    fact
    )
  end

  def side_effect_budget(user:, text:)
    result = @budget_extractor.call(user: user, text: text)
    return nil if result.budget.nil?

    fact = "registrei orçamento #{result.budget.period_type} de #{Formatters::Brl.call(result.budget.limit_amount)} " \
           "(#{result.budget.period_start.strftime('%d/%m')} a #{result.budget.period_end.strftime('%d/%m')})."

    SideEffect.new(
      payload: { budget_id: result.budget.id, confidence: result.confidence },
      fact:    fact
    )
  end

  def side_effect_category(user:, text:)
    result = @category_extractor.call(user: user, text: text)
    return nil if result.category.nil?

    SideEffect.new(
      payload: { category_id: result.category.id, confidence: result.confidence },
      fact:    "criei a categoria #{result.category.name}."
    )
  end

  def side_effect_installment(user:, text:)
    result = @installment_extractor.call(user: user, text: text)
    return nil if result.installment.nil?

    fact = "registrei compra parcelada de #{Formatters::Brl.call(result.installment.total_amount)} " \
           "em #{result.installment.total_installments}x de #{Formatters::Brl.call(result.installment.monthly_amount)}."

    SideEffect.new(
      payload: {
        transaction_id: result.transaction.id,
        installment_id: result.installment.id,
        confidence:     result.confidence
      },
      fact: fact
    )
  end

  def finalize_user_message(message, intent:, payload:)
    message.update!(status: "completed", intent: intent, payload: payload)
    message.conversation.broadcast_message!(message)
  end
end
