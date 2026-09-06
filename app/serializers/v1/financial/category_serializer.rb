# frozen_string_literal: true

module V1
  module Financial
    class CategorySerializer < Blueprinter::Base
      identifier :id

      view :default do
        fields :name, :whatsapp
      end

      view :extended do
        include_view :default
        fields :created_at, :updated_at
      end
    end
  end
end
