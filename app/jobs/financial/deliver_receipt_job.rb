# frozen_string_literal: true

module Financial
  class DeliverReceiptJob < ApplicationJob
    queue_as :receipts

    URL_HOST_ENV = "APP_URL"

    # @param [Financial::Receipt]
    def perform(receipt)
      configure_url_options

      UseCase::Financial::Receipt::DeliverReceiptUseCase
        .new(provider: Messaging::ProviderFactory.build_outbound)
        .call(receipt: receipt)
    end

    private

    def configure_url_options
      host = ENV[URL_HOST_ENV].presence
      return if host.blank?

      ActiveStorage::Current.url_options = { host: host }
    end
  end
end
