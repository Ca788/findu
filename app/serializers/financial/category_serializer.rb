# frozen_string_literal: true

module Financial
  class CategorySerializer < Blueprinter::Base
    identifier :id

    view :default do
      fields :name
    end

    view :extended do
      include_view :default
      fields :created_at, :updated_at
    end
  end
end
