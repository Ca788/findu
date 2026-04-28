# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ocr::Stub::Provider do
  subject(:provider) { described_class.new }

  describe '#extract' do
    it 'returns a Result struct' do
      expect(provider.extract("any/path.jpg")).to be_a(Ocr::Result)
    end

    it 'returns deterministic stub fields' do
      result = provider.extract("any/path.jpg")

      expect(result.amount).to eq(42.50)
      expect(result.description).to eq("Stubbed receipt")
      expect(result.confidence).to eq(1.0)
      expect(result.metadata).to include(provider: "stub")
    end
  end
end
