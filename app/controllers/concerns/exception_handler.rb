# frozen_string_literal: true

module ExceptionHandler
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError do |e|
      Rails.logger.error(e)
      handle_exception(e, :internal_server_error, ErrorMapper.unknown_error)
    end

    rescue_from ActiveRecord::RecordNotFound do |e|
      handle_exception(e, :not_found, ErrorMapper.record_not_found)
    end

    rescue_from ActiveRecord::RecordInvalid do |e|
      messages = e.record&.errors&.full_messages&.join(", ") || e.message
      handle_validation_exception(messages, ErrorMapper.record_invalid)
    end

    rescue_from ActiveRecord::RecordNotUnique do |_e|
      handle_validation_exception("Record already exists.", ErrorMapper.record_not_unique)
    end

    rescue_from ActionController::ParameterMissing do |e|
      Rails.logger.error(e)
      handle_validation_exception(e.message, ErrorMapper.missing_parameter)
    end
  end

  private

  def handle_exception(exception, status, error)
    Rails.logger.error(exception)
    render json: ApiResponseSerializer.render(
      {},
      success: false,
      message: error.message,
      error_code: error.code
    ), status: status
  end

  def handle_validation_exception(message, error)
    render json: ApiResponseSerializer.render(
      {},
      success: false,
      message: message,
      error_code: error.code
    ), status: :unprocessable_entity
  end
end
