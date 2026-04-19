# frozen_string_literal: true

class UseCase::Organization::CreateOrganizationUseCase
  # @param [String] name
  # @param [String] plan
  # @return [Organization]
  def call(name:, plan: nil)
    Organization.create!(name: name, plan: plan)
  rescue ActiveRecord::RecordInvalid => e
    raise StandardError, e.record.errors.full_messages.join(", ")
  end
end
