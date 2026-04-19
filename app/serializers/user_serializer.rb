# frozen_string_literal: true

class UserSerializer < Blueprinter::Base
  identifier :id

  fields :name, :email, :phone, :created_at, :updated_at
end
