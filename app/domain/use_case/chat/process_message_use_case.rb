# frozen_string_literal: true

class UseCase::Chat::ProcessMessageUseCase
  TRANSACTION_CONFIDENCE_THRESHOLD = 0.5
  INTENT_CONFIDENCE_THRESHOLD      = 0.4

  HandlerResult = Struct.new(:body, :payload, keyword_init: true)

  # @param [UseCase::Chat::ClassifyIntentUseCase]
  # @param [UseCase::Chat::TranscribeMessageUseCase]
  # @param [UseCase::Messaging::ExtractTransactionFromMessageUseCase]
  # @param [UseCase::Chat::ExtractBudgetUseCase]
  # @param [UseCase::Chat::ExtractCategoryUseCase]
  # @param [UseCase::Chat::ExtractInstallmentUseCase]
  # @param [UseCase::Chat::AnswerQueryUseCase]
  # @param [UseCase::Financial::Transaction::CreateTransactionUseCase]
  # @param [UseCase::Financial::Category::FindOrCreateByNameUseCase]
  # @param [Module]
  def initialize(classifier: UseCase::Chat::ClassifyIntentUseCase.new,
                 transcriber: UseCase::Chat::TranscribeMessageUseCase.new,
                 transaction_extractor: UseCase::Messaging::ExtractTransactionFromMessageUseCase.new,
                 budget_extractor: UseCase::Chat::ExtractBudgetUseCase.new,
                 category_extractor: UseCase::Chat::ExtractCategoryUseCase.new,
                 installment_extractor: UseCase::Chat::ExtractInstallmentUseCase.new,
                 query_answerer: UseCase::Chat::AnswerQueryUseCase.new,
                 transaction_creator: UseCase::Financial::Transaction::CreateTransactionUseCase.new,
                 category_finder: UseCase::Financial::Category::FindOrCreateByNameUseCase.new,
                 reply_formatter: Chat::Replies::Formatter)
    @classifier            = classifier
    @transcriber           = transcriber
    @transaction_extractor = transaction_extractor
    @budget_extractor      = budget_extractor
    @category_extractor    = category_extractor
    @installment_extractor = installment_extractor
    @query_answerer        = query_answerer
    @transaction_creator   = transaction_creator
    @category_finder       = category_finder
    @reply_formatter       = reply_formatter
  end

  # @param [Chat::Message]
  # @return [Chat::Message]
  def call(message:)
    message.update!(status: "processing")

    transcription_metadata = transcribe_if_audio(message)
    classification         = @classifier.call(text: message.body)
    effective_intent       = effective_intent_from(classification)

    handler_result = handle(user: message.user, intent: effective_intent, text: message.body)

    payload = handler_result.payload.merge(
      intent_confidence: classification.confidence,
      transcription:     transcription_metadata
    ).compact

    finalize_user_message(message, intent: effective_intent, payload: payload)
    create_assistant_reply(message, body: handler_result.body, intent: effective_intent, payload: payload)
  rescue StandardError => e
    message.update!(
      status: "failed",
      error:  { class: e.class.name, message: e.message }
    )
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

  def handle(user:, intent:, text:)
    handler = intent_dispatch[intent]
    return HandlerResult.new(body: @reply_formatter.fallback, payload: {}) if handler.nil?

    handler.call(user: user, text: text, intent: intent)
  end

  def intent_dispatch
    @intent_dispatch ||= {
      "create_transaction" => method(:handle_transaction),
      "create_budget"      => method(:handle_budget),
      "create_category"    => method(:handle_category),
      "create_installment" => method(:handle_installment),
      "query_balance"      => method(:handle_query),
      "query_budget"       => method(:handle_query)
    }
  end

  def handle_transaction(user:, text:, **)
    result = @transaction_extractor.call(text: text)

    if result.amount.blank? || result.confidence.to_f < TRANSACTION_CONFIDENCE_THRESHOLD
      return HandlerResult.new(body: @reply_formatter.fallback, payload: { confidence: result.confidence.to_f })
    end

    category    = @category_finder.call(user: user, name: result.category.presence || result.description.presence)
    transaction = @transaction_creator.call(
      user:             user,
      amount:           result.amount,
      transaction_type: result.transaction_type,
      description:      result.description,
      occurred_at:      result.occurred_at || Time.current,
      category_id:      category&.id
    )

    HandlerResult.new(
      body:    @reply_formatter.transaction(transaction),
      payload: {
        transaction_id: transaction.id,
        category_id:    category&.id,
        confidence:     result.confidence.to_f
      }.compact
    )
  end

  def handle_budget(user:, text:, **)
    result = @budget_extractor.call(user: user, text: text)
    return HandlerResult.new(body: @reply_formatter.fallback, payload: { confidence: result.confidence }) if result.budget.nil?

    HandlerResult.new(
      body:    @reply_formatter.budget(result.budget),
      payload: { budget_id: result.budget.id, confidence: result.confidence }
    )
  end

  def handle_category(user:, text:, **)
    result = @category_extractor.call(user: user, text: text)
    return HandlerResult.new(body: @reply_formatter.fallback, payload: { confidence: result.confidence }) if result.category.nil?

    HandlerResult.new(
      body:    "Categoria salva: #{result.category.name}.",
      payload: { category_id: result.category.id, confidence: result.confidence }
    )
  end

  def handle_installment(user:, text:, **)
    result = @installment_extractor.call(user: user, text: text)
    return HandlerResult.new(body: @reply_formatter.fallback, payload: { confidence: result.confidence }) if result.installment.nil?

    HandlerResult.new(
      body: @reply_formatter.installment(result.transaction, result.installment),
      payload: {
        transaction_id: result.transaction.id,
        installment_id: result.installment.id,
        confidence:     result.confidence
      }
    )
  end

  def handle_query(user:, intent:, **)
    result = @query_answerer.call(user: user, intent: intent)
    HandlerResult.new(body: result.body, payload: result.payload)
  end

  def finalize_user_message(message, intent:, payload:)
    message.update!(status: "completed", intent: intent, payload: payload)
  end

  def create_assistant_reply(parent, body:, intent:, payload:)
    parent.conversation.messages.create!(
      user:           parent.user,
      role:           "assistant",
      kind:           "text",
      status:         "completed",
      body:           body,
      intent:         intent,
      payload:        payload,
      parent_message: parent
    )
  end
end
