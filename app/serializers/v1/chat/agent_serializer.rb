# frozen_string_literal: true

module V1
  module Chat
    class AgentSerializer < Blueprinter::Base
      identifier :id do |agent|
        agent.id.to_s
      end

      view :default do
        fields :name, :persona_extension

        field :tool_count do |agent|
          agent.tool_classes.size
        end

        field :tool_names do |agent|
          agent.tool_classes.map { |klass| klass.name.demodulize.sub(/Tool\z/, "").underscore }
        end
      end
    end
  end
end
