# frozen_string_literal: true

class UseCase::Artifact::CreateArtifactUseCase
  # @param [User] user
  # @param [ActionDispatch::Http::UploadedFile] file
  # @param [String] artifact_type
  # @param [String, nil] source
  # @return [Artifact]
  def call(user:, file:, artifact_type:, source: nil)
    raise ArgumentError, "file is required" if file.blank?

    artifact = user.artifacts.create!(
      artifact_type: artifact_type,
      source: source,
      status: "pending"
    )

    artifact.file.attach(file)

    Artifacts::ProcessOcrJob.perform_later(artifact)

    artifact
  end
end
