# frozen_string_literal: true

module Ocr
  module Gemini
    class ImageResolver
      # @param [String, IO, ActionDispatch::Http::UploadedFile] image
      # @return [String]
      def call(image)
        return image if image.is_a?(String)
        return image.path if image.respond_to?(:path)

        raise ArgumentError, "Unsupported image input: #{image.class}"
      end
    end
  end
end
