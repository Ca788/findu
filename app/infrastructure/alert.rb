# frozen_string_literal: true

class Alert
  # @param [String] message
  # @param [Hash] options { context: {...} }
  # @return [void]
  def self.notify(message, options = {})
    new(message, options).deliver
  end

  # @param [String] message
  # @param [Hash] options
  def initialize(message, options)
    @message = decorate_message(message.to_s)
    @context = options[:context] || {}
  end

  def deliver
    return if @message.blank?

    Rails.logger.error(payload.to_json)
  end

  private

  def decorate_message(message)
    Rails.env.production? ? message : "[#{Rails.env.upcase}] - #{message}"
  end

  def payload
    {
      alert: @message,
      env: Rails.env,
      context: @context
    }
  end
end
