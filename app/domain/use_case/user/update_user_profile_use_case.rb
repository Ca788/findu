# frozen_string_literal: true

class UseCase::User::UpdateUserProfileUseCase
  PERMITTED_ATTRIBUTES = %i[name phone].freeze
  TRUTHY_VALUES = ["1", 1, "true", true, "t", "yes"].freeze

  # @param [User] user
  # @param [Hash{Symbol => Object}] attributes
  # @param [ActionDispatch::Http::UploadedFile, Rack::Test::UploadedFile, nil] avatar
  # @param [Boolean, String, nil] remove_avatar
  # @return [User]
  def call(user:, attributes: {}, avatar: nil, remove_avatar: false)
    raise ArgumentError, "User is required" if user.blank?

    sanitized = sanitize(attributes)
    avatar_action = avatar_action_for(avatar: avatar, remove_avatar: remove_avatar)

    if sanitized.empty? && avatar_action == :none
      raise ArgumentError, "No attributes to update"
    end

    User.transaction do
      user.update!(sanitized) if sanitized.any?
      apply_avatar(user: user, action: avatar_action, avatar: avatar)
    end

    user
  end

  private

  # @param [Hash] attributes
  # @return [Hash{Symbol => Object}]
  def sanitize(attributes)
    return {} if attributes.blank?

    attributes
      .symbolize_keys
      .slice(*PERMITTED_ATTRIBUTES)
      .each_with_object({}) do |(key, value), acc|
        next if value.nil?

        acc[key] = value.is_a?(String) ? value.strip : value
      end
  end

  # @return [Symbol] :attach, :remove or :none
  def avatar_action_for(avatar:, remove_avatar:)
    return :attach if avatar.present?
    return :remove if TRUTHY_VALUES.include?(remove_avatar)

    :none
  end

  def apply_avatar(user:, action:, avatar:)
    case action
    when :attach
      user.avatar.attach(avatar)
      raise ActiveRecord::RecordInvalid, user unless user.valid?
    when :remove
      user.avatar.purge_later if user.avatar.attached?
    end
  end
end
