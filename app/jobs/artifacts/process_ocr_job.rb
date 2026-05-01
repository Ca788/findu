# frozen_string_literal: true

class Artifacts::ProcessOcrJob < ApplicationJob
  queue_as :artifacts_ocr

  sidekiq_options retry: 3, dead: true

  rescue_from(StandardError) do |error|
    artifact = arguments[0]

    context_info = {
      artifact_id: artifact&.id,
      user_id: artifact&.user_id,
      artifact_type: artifact&.artifact_type,
      job_name: self.class.name,
      job_arguments: self.arguments,
      error_message: error.message,
      error_backtrace: error.backtrace&.take(10),
      job_scheduled_at: self.scheduled_at,
      job_executions: self.executions,
      job_queue: self.queue_name
    }

    Alert.notify(
      "Artifacts::ProcessOcrJob failed!",
      context: context_info
    )

    raise error
  end

  # @param [Artifact] artifact
  def perform(artifact)
    artifact = UseCase::Artifact::ExtractArtifactDataUseCase.new.call(artifact: artifact)
    UseCase::Artifact::CreateTransactionFromArtifactUseCase.new.call(artifact: artifact)
  end
end
