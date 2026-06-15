# frozen_string_literal: true

module Llm
  module Agents
    Agent = Struct.new(:id, :name, :persona_extension, :tool_classes, keyword_init: true) do
      # @param [User]
      # @return [Array<Llm::Tools::BaseTool>]
      def build_tools(user)
        tool_classes.map { |klass| klass.new(user: user) }
      end
    end
  end
end
