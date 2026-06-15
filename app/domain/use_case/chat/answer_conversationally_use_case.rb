# frozen_string_literal: true

class UseCase::Chat::AnswerConversationallyUseCase
  class StreamAlreadyStartedError < StandardError; end

  HISTORY_LIMIT          = 20
  STREAM_FLUSH_SECONDS   = 0.08
  FALLBACK_BODY          = "Desculpe, tive um problema agora. Pode repetir?"
  RATE_LIMIT_BODY        = "Atingi o limite de requisições do modelo de IA agora. " \
                           "Tente de novo em alguns segundos — ou aumente a cota do Gemini."

  # @param [UseCase::Chat::BuildUserContextUseCase]
  # @param [Llm::Prompts::ChatAgentPromptBuilder]
  # @param [Array<String>]
  def initialize(context_builder: UseCase::Chat::BuildUserContextUseCase.new,
                 prompt_builder: Llm::Prompts::ChatAgentPromptBuilder.new,
                 models: Llm::Models.chain("CHAT_AGENT_MODEL"))
    @context_builder = context_builder
    @prompt_builder  = prompt_builder
    @models          = models
  end

  # @param [Chat::Message]
  # @param [Array<String>]
  # @param [Llm::Agents::Agent, nil]
  # @return [Chat::Message]
  def call(user_message:, side_facts: [], agent: nil)
    user           = user_message.user
    selected_agent = agent || Llm::Agents::Registry::DEFAULT
    reply          = build_streaming_reply(user_message)

    context     = @context_builder.call(user: user)
    system_text = @prompt_builder.call(context: context, side_facts: side_facts, agent: selected_agent)
    history     = history_messages(user_message)

    final_body = Llm::ModelFallback.with_fallback(@models) do |model|
      chat = build_chat(model: model, system_text: system_text, history: history, user: user, agent: selected_agent)
      stream_response(chat: chat, user_message: user_message, reply: reply)
    end

    finalize_reply(reply, body: final_body)
    reply
  rescue RubyLLM::RateLimitError, StreamAlreadyStartedError => e
    Rails.logger.warn("[AnswerConversationallyUseCase] rate limit: #{e.message}")
    finalize_reply(reply, body: RATE_LIMIT_BODY) if reply
    reply
  rescue StandardError => e
    Rails.logger.error("[AnswerConversationallyUseCase] #{e.class}: #{e.message}")
    finalize_reply(reply, body: FALLBACK_BODY, error: { class: e.class.name, message: e.message }) if reply
    reply
  end

  private

  def build_chat(model:, system_text:, history:, user:, agent:)
    chat = Llm::GeminiChat.for(model)
                          .with_instructions(system_text)
                          .with_tools(*agent.build_tools(user))
    history.each { |m| chat.add_message(role: m.role.to_sym, content: m.body.to_s) }
    chat
  end

  def build_streaming_reply(user_message)
    reply = user_message.conversation.messages.create!(
      user:           user_message.user,
      role:           "assistant",
      kind:           "text",
      status:         "processing",
      body:           "",
      parent_message: user_message
    )
    user_message.conversation.broadcast_message!(reply)
    reply
  end

  def history_messages(user_message)
    user_message.conversation.messages
                .where(status: "completed")
                .where.not(id: user_message.id)
                .where(role: %w[user assistant])
                .where.not(body: [nil, ""])
                .order(created_at: :asc)
                .last(HISTORY_LIMIT)
  end

  def stream_response(chat:, user_message:, reply:)
    buffer        = +""
    flushed_upto  = 0
    last_flush_at = Time.current
    attachment_paths = resolve_attachment_paths(user_message)

    chat.ask(user_message.body.to_s, with: attachment_paths) do |chunk|
      buffer << chunk.content.to_s
      now = Time.current
      next unless (now - last_flush_at) >= STREAM_FLUSH_SECONDS

      flush_delta!(reply, buffer, flushed_upto)
      flushed_upto  = buffer.length
      last_flush_at = now
    end

    buffer.presence || FALLBACK_BODY
  rescue RubyLLM::RateLimitError
    raise if flushed_upto.zero?

    raise StreamAlreadyStartedError
  end

  def flush_delta!(reply, buffer, flushed_upto)
    delta = buffer[flushed_upto..]
    return if delta.blank?

    reply.conversation.broadcast_delta!(reply.id, delta)
  end

  def finalize_reply(reply, body:, error: nil)
    reply.update!(
      body:   body,
      status: error ? "failed" : "completed",
      error:  error
    )
    reply.conversation.broadcast_message!(reply)
  end

  def resolve_attachment_paths(message)
    return [] unless message.attachments.attached?

    message.attachments.map do |att|
      path = ActiveStorage::Blob.service.path_for(att.key)
      path if File.exist?(path)
    end.compact
  end
end
