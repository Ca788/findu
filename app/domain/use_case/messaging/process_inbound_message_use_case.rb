# frozen_string_literal: true

class UseCase::Messaging::ProcessInboundMessageUseCase
  CONFIDENCE_THRESHOLD = 0.5

  # @param [Messaging::Provider]
  # @param [UseCase::Messaging::ExtractTransactionFromMessageUseCase]
  def initialize(provider:, extractor: UseCase::Messaging::ExtractTransactionFromMessageUseCase.new)
    @provider  = provider
    @extractor = extractor
  end

  # @param [Messaging::Message]
  # @return [void]
  def call(message:)
    user = User.find_by(phone: message.from)

    unless user
      @provider.send_message(to: message.reply_to, body: reply_user_not_found)
      return
    end

    if message.media.present?
      handle_image(user, message)
    else
      handle_text(user, message)
    end
  end

  private

  def handle_image(user, message)
    attachment = @provider.fetch_media(**message.media.first)
    UseCase::Artifact::CreateArtifactUseCase.new.call(
      user:          user,
      file:          attachment,
      artifact_type: "receipt",
      source:        "whatsapp",
      raw_data:      { "reply_to" => message.reply_to }
    )
    @provider.send_message(to: message.reply_to, body: reply_image_received)
  end

  def handle_text(user, message)
    result = @extractor.call(message: message)

    if result.amount.blank? || result.confidence < CONFIDENCE_THRESHOLD
      @provider.send_message(to: message.reply_to, body: reply_parse_error)
      return
    end

    transaction = ApplicationRecord.transaction do
      category = find_or_create_category(user, result.description)

      UseCase::Financial::Transaction::CreateTransactionUseCase.new.call(
        user:             user,
        amount:           result.amount,
        transaction_type: result.transaction_type,
        description:      result.description,
        occurred_at:      result.occurred_at || Time.current,
        category_id:      category&.id
      )
    end

    @provider.send_message(to: message.reply_to, body: reply_success(transaction))
  end

  def find_or_create_category(user, description)
    return nil if description.blank?

    user.categories.find_or_create_by!(name: description)
  end

  def reply_user_not_found
    "Número não cadastrado. Acesse o app para criar sua conta."
  end

  def reply_parse_error
    "Não entendi. Tente: \"gastei R$50 no mercado\" ou \"recebi R$200 de salário\"."
  end

  def reply_image_received
    "Recibo recebido! Estou processando... te aviso quando estiver pronto."
  end

  def reply_success(transaction)
    type     = transaction.expense? ? "Despesa" : "Receita"
    value    = format("R$%.2f", transaction.amount).gsub(".", ",")
    category = transaction.category ? " [#{transaction.category.name}]" : ""
    "#{type} registrada: #{value}#{" - #{transaction.description}" if transaction.description.present?}#{category}"
  end
end
