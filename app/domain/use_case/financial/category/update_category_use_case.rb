# frozen_string_literal: true

class UseCase::Financial::Category::UpdateCategoryUseCase
  # @param [User] user
  # @param [String] id
  # @param [Hash] attributes
  # @return [Financial::Category]
  def call(user:, id:, attributes:)
    category = user.categories.find(id)
    category.update!(attributes.slice(:name))
    category
  end
end
