# frozen_string_literal: true

class UseCase::Financial::Category::FindOrCreateByNameUseCase
  MAX_NAME_LENGTH = 40

  # @param [UseCase::Financial::Category::CreateCategoryUseCase]
  def initialize(creator: UseCase::Financial::Category::CreateCategoryUseCase.new)
    @creator = creator
  end

  # @param [User]
  # @param [String, nil]
  # @return [Financial::Category, nil]
  def call(user:, name:)
    sanitized = name.to_s.strip
    return nil if sanitized.blank? || sanitized.length > MAX_NAME_LENGTH

    existing = user.categories.where("LOWER(name) = ?", sanitized.downcase).first
    return existing if existing

    @creator.call(user: user, name: sanitized)
  end
end
