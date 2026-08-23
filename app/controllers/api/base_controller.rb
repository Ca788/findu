# frozen_string_literal: true

module Api
  class BaseController < ActionController::API
    include ExceptionHandler
    include PaginationParams

    SERIALIZER_VIEWS = %i[default extended].freeze

    before_action :authenticate_user!
    before_action :set_user

    private

    def set_user
      @user = current_user
    end

    # @param [Symbol]
    # @param [Array<Symbol>]
    # @return [Symbol]
    def serializer_view_param(default: :default, allowed: SERIALIZER_VIEWS)
      requested = params[:view].to_s.downcase.to_sym
      allowed.include?(requested) ? requested : default
    end
  end
end
