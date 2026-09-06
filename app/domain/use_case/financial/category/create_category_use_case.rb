# frozen_string_literal: true

class UseCase::Financial::Category::CreateCategoryUseCase
  # @param [User]
  # @param [String]
  # @param [String, nil]
  # @return [Financial::Category]
  def call(user:, name:, whatsapp: nil)
    user.categories.create!(name: name, whatsapp: whatsapp)
  end
end
