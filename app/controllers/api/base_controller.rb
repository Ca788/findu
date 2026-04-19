# frozen_string_literal: true

module Api
  class BaseController < ActionController::API
    include ExceptionHandler
    include PaginationParams

    before_action :authenticate_user!
    before_action :set_user

    private

    def set_user
      @user = current_user
    end
  end
end
