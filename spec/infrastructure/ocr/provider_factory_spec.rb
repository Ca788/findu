# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ocr::ProviderFactory do
  describe '.build' do
    context 'when OCR_PROVIDER is unset' do
      before { ENV.delete("OCR_PROVIDER") }

      it 'defaults to Gemini::Provider' do
        expect(described_class.build).to be_a(Ocr::Gemini::Provider)
      end
    end

    context 'when OCR_PROVIDER is "gemini"' do
      before { ENV["OCR_PROVIDER"] = "gemini" }
      after  { ENV.delete("OCR_PROVIDER") }

      it 'returns Gemini::Provider' do
        expect(described_class.build).to be_a(Ocr::Gemini::Provider)
      end
    end

    context 'when OCR_PROVIDER is unknown' do
      before { ENV["OCR_PROVIDER"] = "unknown" }
      after  { ENV.delete("OCR_PROVIDER") }

      it 'raises' do
        expect { described_class.build }.to raise_error(/Unsupported OCR provider/)
      end
    end
  end
end
