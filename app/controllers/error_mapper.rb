# frozen_string_literal: true

module ErrorMapper
  class Error
    attr_reader :code, :message

    def initialize(code, message)
      @code = code
      @message = message
    end

    def title
      @message
    end

    def description
      nil
    end
  end

  ERRORS = {
    unknown_error: Error.new(500, "Unknown Error"),
    record_not_found: Error.new(404, "Record Not Found"),
    record_invalid: Error.new(1003, "Validation Failed"),
    record_not_unique: Error.new(1004, "Record Already Exists"),
    unauthorized: Error.new(1001, "Invalid credentials"),
    missing_parameter: Error.new(1002, "Missing parameter")
  }.freeze

  ERRORS.each do |key, error|
    define_singleton_method(key) { error }
  end

  def self.unknown_error
    Error.new(500, "Unknown Error")
  end
end
