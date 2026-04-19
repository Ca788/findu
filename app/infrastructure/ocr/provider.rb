# frozen_string_literal: true
module Ocr
  class Provider
    # @param [String, IO] image path or IO of the receipt/screenshot
    # @return [Ocr::Result]
    def extract(image)
      raise NotImplementedError, "#{self.class.name} must implement #extract"
    end
  end
end
