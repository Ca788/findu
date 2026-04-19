# frozen_string_literal: true

class OrganizationSerializer < Blueprinter::Base
  identifier :id

  fields :name, :plan, :created_at, :updated_at
end
