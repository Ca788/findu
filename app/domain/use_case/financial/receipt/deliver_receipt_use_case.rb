# frozen_string_literal: true

class UseCase::Financial::Receipt::DeliverReceiptUseCase
  class MissingFileError < StandardError; end

  URL_TTL = 24.hours

  # @param [Messaging::Twilio::Provider, Messaging::WhatsappCloud::Provider]
  def initialize(provider:)
    @provider = provider
  end

  # @param [Financial::Receipt]
  # @raise [MissingFileError]
  # @return [Financial::Receipt]
  def call(receipt:)
    raise MissingFileError, "Receipt #{receipt.id} has no rendered file" unless receipt.file.attached?

    phone = Support::Phone.e164(receipt.payer_phone)
    raise ArgumentError, "receipt whatsapp is invalid" if phone.blank?

    deliver(receipt, phone)
    receipt.update!(status: "sent", sent_at: Time.current, payer_phone: phone)
    receipt
  rescue StandardError => e
    record_failure(receipt, e)
    raise
  end

  private

  def deliver(receipt, phone)
    body = Chat::Replies::Formatter.receipt(receipt)

    if @provider.respond_to?(:send_document)
      @provider.send_document(
        to:           phone,
        body:         body,
        filename:     receipt.filename,
        content_type: ::Financial::Receipt::CONTENT_TYPE,
        io:           StringIO.new(receipt.file.download)
      )
      return
    end

    @provider.send_media(
      to:        phone,
      body:      body,
      media_url: receipt.file.url(expires_in: URL_TTL)
    )
  end

  def record_failure(receipt, error)
    receipt.update_columns(
      status:     "failed",
      metadata:   receipt.metadata.merge("delivery_error" => error.message),
      updated_at: Time.current
    )
  end
end
