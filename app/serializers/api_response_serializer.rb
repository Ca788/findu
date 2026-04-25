# frozen_string_literal: true

class ApiResponseSerializer < Blueprinter::Base
  DEFAULT_OPTIONS = { success: true }.freeze

  class << self
    def render_data_array(objects, options = {})
      render({ data_array: objects }, options)
    end

    def error(error_obj, options = {})
      render({}, { success: false, error: error_obj }.merge(options))
    end

    def when_option(key)
      ->(_field_name, _object, options) { options[key].present? }
    end
  end

  field :success do |_object, options|
    options.fetch(:success, DEFAULT_OPTIONS[:success])
  end

  field(:message,       if: when_option(:message))       { |_o, opts| opts[:message] }
  field(:errorCode,     if: when_option(:error_code))    { |_o, opts| opts[:error_code] }
  field(:pagination,    if: when_option(:pagination))    { |_o, opts| opts[:pagination] }
  field(:filterOptions, if: when_option(:filterOptions)) { |_o, opts| opts[:filterOptions] }
  field(:metadata,      if: when_option(:metadata))      { |_o, opts| opts[:metadata] }

  field :error, if: when_option(:error) do |_object, options|
    err = options[:error]
    {
      code: err.code,
      title: err.title,
      description: err.description
    }.compact
  end

  field :data, if: ->(_field_name, object, _options) { object.present? } do |object, options|
    object = object[:data_array] if object.is_a?(Hash) && object.key?(:data_array)

    if options[:serializer].present?
      options[:serializer].render_as_hash(
        object,
        options.merge(view: options[:serializer_view])
      )
    else
      object
    end
  end
end
