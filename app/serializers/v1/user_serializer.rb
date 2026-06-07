# frozen_string_literal: true

module V1
  class UserSerializer < Blueprinter::Base
    identifier :id

    fields :name, :email, :phone, :created_at, :updated_at

    field :avatar_url do |user|
      next nil unless user.avatar.attached?

      Rails.application.routes.url_helpers.rails_blob_path(user.avatar, only_path: true)
    end
  end
end
