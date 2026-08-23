# frozen_string_literal: true

module Intelligence
  class GenerateUserInsightsJob < ApplicationJob
    queue_as :insights

    # @param [User]
    # @param [String, nil]
    def perform(user, month = nil)
      UseCase::Intelligence::GenerateInsightsUseCase.new.call(user: user, month: month)
    end
  end
end
