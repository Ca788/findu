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

    rescue_from ActionController::ParameterMissing do |e|
      Rails.logger.error(e)
      render json: ApiResponseSerializer.render(
        {},
        success: false,
        message: e.message,
        error_code: ErrorMapper.missing_parameter.code
      ), status: :bad_request
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
end
