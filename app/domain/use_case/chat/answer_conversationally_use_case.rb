# frozen_string_literal: true

class UseCase::Chat::AnswerConversationallyUseCase
  DEFAULT_MODEL          = "gemini-2.5-flash"
  HISTORY_LIMIT          = 20
  STREAM_FLUSH_CHARS     = 80
  STREAM_FLUSH_SECONDS   = 0.4
  FALLBACK_BODY          = "Desculpe, tive um problema agora. Pode repetir?"

  # @param [UseCase::Chat::BuildUserContextUseCase] context_builder
  # @param [Llm::Prompts::ChatAgentPromptBuilder] prompt_builder
  # @param [String] model
  def initialize(context_builder: UseCase::Chat::BuildUserContextUseCase.new,
                 prompt_builder: Llm::Prompts::ChatAgentPromptBuilder.new,
                 model: ENV.fetch("CHAT_AGENT_MODEL", DEFAULT_MODEL))
    @context_builder = context_builder
    @prompt_builder  = prompt_builder
    @model           = model
  end

  # @param [Chat::Message] user_message
  # @param [Array<String>] side_facts  facts to inject in the system prompt
  # @return [Chat::Message]  the assistant reply
  def call(user_message:, side_facts: [])
    user = user_message.user
    reply = build_streaming_reply(user_message)

    context     = @context_builder.call(user: user)
    system_text = @prompt_builder.call(context: context, side_facts: side_facts)
    history     = history_messages(user_message)

    chat = RubyLLM.chat(model: @model).with_instructions(system_text)
    history.each { |m| chat.add_message(role: m.role.to_sym, content: m.body.to_s) }

    final_body = stream_response(chat: chat, user_message: user_message, reply: reply)

    finalize_reply(reply, body: final_body)
    reply
  rescue StandardError => e
    Rails.logger.error("[AnswerConversationallyUseCase] #{e.class}: #{e.message}")
    finalize_reply(reply, body: FALLBACK_BODY, error: { class: e.class.name, message: e.message }) if reply
    reply
  end

  private

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
    last_flushed  = +""
    last_flush_at = Time.current
    attachment_paths = resolve_attachment_paths(user_message)

    chat.ask(user_message.body.to_s, with: attachment_paths) do |chunk|
      buffer << chunk.content.to_s
      now = Time.current
      next unless should_flush?(buffer, last_flushed, last_flush_at, now)

      flush!(reply, buffer)
      last_flushed  = buffer.dup
      last_flush_at = now
    end

    buffer.presence || FALLBACK_BODY
  end

  def should_flush?(buffer, last_flushed, last_flush_at, now)
    return true if (buffer.length - last_flushed.length) >= STREAM_FLUSH_CHARS
    (now - last_flush_at) >= STREAM_FLUSH_SECONDS && buffer != last_flushed
  end

  def flush!(reply, body)
    reply.update_columns(body: body, updated_at: Time.current)
    reply.conversation.broadcast_message!(reply)
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
