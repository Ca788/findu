# frozen_string_literal: true

class UseCase::Financial::Receipt::DeliverReceiptUseCase
  class MissingFileError < StandardError; end

  URL_TTL = 24.hours

  # @param [Messaging::Provider]
  def initialize(provider:)
    @provider = provider
  end

  # @param [Financial::Receipt]
  # @raise [MissingFileError]
  # @return [Financial::Receipt]
  def call(receipt:)
    raise MissingFileError, "Receipt #{receipt.id} has no rendered file" unless receipt.file.attached?

    @provider.send_media(
      to:        receipt.payer_phone,
      body:      Chat::Replies::Formatter.receipt(receipt),
      media_url: receipt.file.url(expires_in: URL_TTL)
    )

    receipt.update!(status: "sent", sent_at: Time.current)
    receipt
  rescue StandardError => e
    record_failure(receipt, e)
    raise
  end

  private

  def record_failure(receipt, error)
    receipt.update_columns(
      status:     "failed",
      metadata:   receipt.metadata.merge("delivery_error" => error.message),
      updated_at: Time.current
    )
  end
end
