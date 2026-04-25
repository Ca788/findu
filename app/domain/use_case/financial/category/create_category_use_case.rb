# frozen_string_literal: true

class UseCase::Financial::Category::CreateCategoryUseCase
  # @param [User] user
  # @param [String] name
  # @return [Financial::Category]
  def call(user:, name:)
    user.categories.create!(name: name)
  end
end
