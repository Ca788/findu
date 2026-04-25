# frozen_string_literal: true

class UseCase::Financial::Category::DestroyCategoryUseCase
  # @param [User] user
  # @param [String] id
  # @return [Financial::Category]
  def call(user:, id:)
    category = user.categories.find(id)
    category.destroy!
    category
  end
end
