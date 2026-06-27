# frozen_string_literal: true

require "test_helper"

module Llm
  class ModelFallbackTest < ActiveSupport::TestCase
    test "returns the first model's result without falling back" do
      attempts = []
      result = Llm::ModelFallback.with_fallback(%w[a b c]) do |model|
        attempts << model
        "ok:#{model}"
      end

      assert_equal "ok:a", result
      assert_equal %w[a], attempts
    end

    test "falls back to the next model on rate limit" do
      attempts = []
      result = Llm::ModelFallback.with_fallback(%w[a b c]) do |model|
        attempts << model
        raise RubyLLM::RateLimitError, "429" if model == "a"

        "ok:#{model}"
      end

      assert_equal "ok:b", result
      assert_equal %w[a b], attempts
    end

    test "re-raises the last rate limit error when every model is exhausted" do
      attempts = []
      error = assert_raises(RubyLLM::RateLimitError) do
        Llm::ModelFallback.with_fallback(%w[a b]) do |model|
          attempts << model
          raise RubyLLM::RateLimitError, "limit on #{model}"
        end
      end

      assert_equal %w[a b], attempts
      assert_equal "limit on b", error.message
    end

    test "does not rescue errors other than rate limits" do
      attempts = []
      assert_raises(RuntimeError) do
        Llm::ModelFallback.with_fallback(%w[a b]) do |model|
          attempts << model
          raise "boom"
        end
      end

      assert_equal %w[a], attempts, "must not try the next model on a non-rate-limit error"
    end

    test "accepts a single model string" do
      result = Llm::ModelFallback.with_fallback("solo") { |model| "ok:#{model}" }

      assert_equal "ok:solo", result
    end

    test "raises ArgumentError on an empty chain" do
      assert_raises(ArgumentError) { Llm::ModelFallback.with_fallback([]) { "x" } }
      assert_raises(ArgumentError) { Llm::ModelFallback.with_fallback([nil, ""]) { "x" } }
    end
  end
end
