# frozen_string_literal: true

class ApiResponseSerializer < Blueprinter::Base

  DEFAULT_OPTIONS = { success: true }.freeze

  class << self
    def render_data_array(objects, options = {})
      render({ data_array: objects }, options)
    end

    def success(data = nil, options = {})
      render({ data: data }, { success: true }.merge(options))
    end

    def error(error_obj, options = {})
      render_options = { success: false, error: error_obj }.merge(options)
      render({}, render_options)
    end

    private

    def extract_data_array(object)
      return object[:data_array] if object.is_a?(Hash) && object.key?(:data_array)
      object
    end

    def prepare_data_options(options)
      return options unless options[:serializer]

      options.merge(view: options[:serializer_view])
    end
  end

  field :success do |_object, options|
    options.fetch(:success, DEFAULT_OPTIONS[:success])
  end

  field :message, if: ->(_field_name, _object, options) { options[:message].present? } do |_object, options|
    options[:message]
  end

  field :error, if: ->(_field_name, _object, options) { options[:error].present? } do |_object, options|
    error = options[:error]
    {
      code: error.code,
      title: error.title,
      description: error.description
    }.compact
  end

  field :errorCode, if: ->(_field_name, _object, options) { options[:error_code].present? } do |_object, options|
    options[:error_code]
  end

  field :pagination, if: ->(_field_name, _object, options) { options[:pagination].present? } do |_object, options|
    options[:pagination]
  end

  field :filterOptions, if: ->(_field_name, _object, options) { options[:filterOptions].present? } do |_object, options|
    options[:filterOptions]
  end

  field :data, if: ->(_field_name, object, _options) { object.present? } do |object, options|
    data_object = extract_data_array(object)

    if options[:serializer]
      serialized = options[:serializer].render_as_hash(
        data_object,
        prepare_data_options(options)
      )
      serialized[:data] || serialized
    else
      data_object
    end
  end

  field :metadata, if: ->(_field_name, _object, options) { options[:metadata].present? } do |_object, options|
    options[:metadata]
  end
end
