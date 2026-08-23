# frozen_string_literal: true

module Intelligence
  class EnqueueInsightsJob < ApplicationJob
    queue_as :insights

    BATCH_SIZE = 100

    # @param [String, nil]
    def perform(month = nil)
      User.where(deleted_at: nil).find_each(batch_size: BATCH_SIZE) do |user|
        Intelligence::GenerateUserInsightsJob.perform_later(user, month)
      end
    end
  end
end
