# frozen_string_literal: true

class UseCase::Artifact::ExtractArtifactDataUseCase
  CONFIDENCE_THRESHOLD = ENV.fetch("OCR_CONFIDENCE_THRESHOLD", 0.5).to_f

  # @param [Ocr::Provider, nil] provider
  def initialize(provider: nil)
    @provider = provider
  end

  # @param [Artifact] artifact
  # @return [Artifact]
  def call(artifact:)
    raise ArgumentError, "artifact has no attached file" unless artifact.file.attached?

    provider = @provider || Ocr::ProviderFactory.build(artifact_type: artifact.artifact_type)
    result = extract(artifact, provider)

    if result.confidence.to_f >= CONFIDENCE_THRESHOLD
      persist_processed(artifact, result)
    else
      persist_needs_review(artifact, result)
    end

    artifact
  rescue StandardError => e
    persist_failure(artifact, e)
    raise
  end

  private

  # @param [Artifact] artifact
  # @param [Ocr::Provider] provider
  # @return [Ocr::Result]
  def extract(artifact, provider)
    artifact.file.open do |tempfile|
      provider.extract(tempfile)
    end
  end

  # @param [Artifact] artifact
  # @param [Ocr::Result] result
  def persist_processed(artifact, result)
    artifact.update!(
      status: :processed,
      occurred_at: result.occurred_at,
      processed_data: {
        amount:           result.amount&.to_s,
        description:      result.description,
        transaction_type: result.transaction_type,
        raw_text:         result.raw_text,
        confidence:       result.confidence,
        metadata:         result.metadata
      }
    )
  end

  # @param [Artifact] artifact
  # @param [Ocr::Result] result
  def persist_needs_review(artifact, result)
    artifact.update!(
      status: :needs_review,
      occurred_at: result.occurred_at,
      processed_data: {
        amount:           result.amount&.to_s,
        description:      result.description,
        transaction_type: result.transaction_type,
        raw_text:         result.raw_text,
        confidence:       result.confidence,
        metadata:         result.metadata
      }
    )
  end

  # @param [Artifact] artifact
  # @param [StandardError] error
  def persist_failure(artifact, error)
    Rails.logger.error("[Artifact##{artifact.id}] OCR failed: #{error.class} - #{error.message}")
    artifact.update_columns(
      status: "failed",
      processed_data: { error: { class: error.class.name, message: error.message } },
      updated_at: Time.current
    )
  end
end
