# frozen_string_literal: true

module Chat
  module Transcription
    Result = Struct.new(:transcript, :confidence, :metadata, keyword_init: true)
  end
end
