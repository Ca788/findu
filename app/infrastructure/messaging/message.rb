# frozen_string_literal: true

module Messaging
  class MediaFetchError < StandardError; end

  Message = Struct.new(
    :from,
    :reply_to,
    :body,
    :media,
    :raw,
    keyword_init: true
  )
end
