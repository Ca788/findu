# frozen_string_literal: true

class ArtifactSerializer < Blueprinter::Base
  identifier :id

  view :default do
    fields :artifact_type, :status, :source, :occurred_at, :created_at, :updated_at
  end

  view :extended do
    include_view :default

    field :file_url do |artifact|
      next nil unless artifact.file.attached?

      Rails.application.routes.url_helpers.rails_blob_path(artifact.file, only_path: true)
    end

    field :processed_data
  end
end
