# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ocr::ProviderFactory do
  describe '.build' do
    context 'when OCR_PROVIDER is unset' do
      before { ENV.delete("OCR_PROVIDER") }

      it 'defaults to StubProvider' do
        expect(described_class.build).to be_a(Ocr::StubProvider)
      end
    end

    context 'when OCR_PROVIDER is "stub"' do
      before { ENV["OCR_PROVIDER"] = "stub" }
      after  { ENV.delete("OCR_PROVIDER") }

      it 'returns StubProvider' do
        expect(described_class.build).to be_a(Ocr::StubProvider)
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
