# frozen_string_literal: true

module PaginationParams
  extend ActiveSupport::Concern

  def per_page_param(limit: 50, default: 10)
    per_page = params[:perPage]&.to_i || params[:per_page]&.to_i || default
    return default if per_page < 1
    return limit if per_page > limit
    per_page
  end

  def page_param
    page = params[:page]&.to_i || 1
    return 1 if page < 1
    page
  end
end
