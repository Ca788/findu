# frozen_string_literal: true

RubyLLM.configure do |config|
  config.gemini_api_key = ENV["GEMINI_API_KEY"]
  config.request_timeout = ENV.fetch("RUBY_LLM_TIMEOUT", 60).to_i
end
