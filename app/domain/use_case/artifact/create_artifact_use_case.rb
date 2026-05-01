# frozen_string_literal: true

class UseCase::Artifact::CreateArtifactUseCase
  # @param [User]
  # @param [ActionDispatch::Http::UploadedFile]
  # @param [String]
  # @param [String, nil]
  # @param [Hash]
  # @return [Artifact]
  def call(user:, file:, artifact_type:, source: nil, raw_data: {})
    raise ArgumentError, "file is required" if file.blank?

    artifact = user.artifacts.create!(
      artifact_type: artifact_type,
      source: source,
      raw_data: raw_data,
      status: "pending"
    )

    artifact.file.attach(file)

    Artifacts::ProcessOcrJob.perform_later(artifact)

    artifact
  end
end
