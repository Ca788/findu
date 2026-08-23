# frozen_string_literal: true

module V1
  module Intelligence
    class InsightSerializer < Blueprinter::Base
      identifier :id

      view :default do
        fields :content, :severity, :reference_type, :created_at
      end

      view :extended do
        include_view :default
        fields :reference_id, :metadata, :updated_at
      end
    end
  end
end
