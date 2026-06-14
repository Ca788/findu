# frozen_string_literal: true

class UseCase::Financial::Category::ListCategoriesUseCase
  DEFAULT_LIMIT = 100
  MAX_LIMIT     = 200

  # @param [User]
  # @param [String, nil]
  # @param [Integer, nil]
  # @return [ActiveRecord::Relation<Financial::Category>]
  def call(user:, name_like: nil, limit: nil)
    scope = user.categories
    scope = scope.where("name ILIKE ?", "%#{name_like.strip}%") if name_like.is_a?(String) && name_like.strip.present?
    scope.order(name: :asc).limit(clamp_limit(limit))
  end

  private

  def clamp_limit(value)
    n = value.to_i
    return DEFAULT_LIMIT if n <= 0

    [n, MAX_LIMIT].min
  end
end
