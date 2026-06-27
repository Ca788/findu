# frozen_string_literal: true

require "test_helper"

module Llm
  class ModelsTest < ActiveSupport::TestCase
    setup { @env_backup = ENV.to_hash }
    teardown { ENV.replace(@env_backup) }

    test "returns the default chain when no env is set" do
      ENV.delete("CHAT_AGENT_MODEL")
      ENV.delete("GEMINI_MODEL_CHAIN")

      assert_equal Llm::Models::DEFAULT_CHAIN, Llm::Models.chain("CHAT_AGENT_MODEL")
    end

    test "parses the use-case specific env as csv" do
      ENV["CHAT_AGENT_MODEL"] = "gemini-3.5-flash, gemini-3.1-flash-lite"

      assert_equal %w[gemini-3.5-flash gemini-3.1-flash-lite], Llm::Models.chain("CHAT_AGENT_MODEL")
    end

    test "falls back to the global chain env" do
      ENV.delete("CHAT_AGENT_MODEL")
      ENV["GEMINI_MODEL_CHAIN"] = "a,b"

      assert_equal %w[a b], Llm::Models.chain("CHAT_AGENT_MODEL")
    end

    test "the use-case env wins over the global chain" do
      ENV["CHAT_AGENT_MODEL"]  = "specific"
      ENV["GEMINI_MODEL_CHAIN"] = "global"

      assert_equal %w[specific], Llm::Models.chain("CHAT_AGENT_MODEL")
    end

    test "strips whitespace and ignores empty entries" do
      ENV["CHAT_AGENT_MODEL"] = " a , , b ,"

      assert_equal %w[a b], Llm::Models.chain("CHAT_AGENT_MODEL")
    end

    test "returns the default chain when the csv has no usable entries" do
      ENV["CHAT_AGENT_MODEL"] = " , ,"

      assert_equal Llm::Models::DEFAULT_CHAIN, Llm::Models.chain("CHAT_AGENT_MODEL")
    end
  end
end
