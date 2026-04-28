# frozen_string_literal: true

namespace :ocr do
  desc "Extract data from a receipt image. Usage: rails 'ocr:extract[/path/to/receipt.jpg]'"
  task :extract, [:path] => :environment do |_, args|
    path = args[:path]
    abort("Usage: rails 'ocr:extract[/path/to/receipt.jpg]'") if path.blank?
    abort("File not found: #{path}") unless File.exist?(path)

    puts "Provider: #{ENV.fetch('OCR_PROVIDER', 'gemini')}"
    puts "Model:    #{ENV.fetch('GEMINI_OCR_MODEL', Ocr::Gemini::Provider::DEFAULT_MODEL)}"
    puts "File:     #{path}"
    puts "---"

    started = Time.current
    result = Ocr::ProviderFactory.build.extract(path)
    elapsed = (Time.current - started).round(2)

    puts "Elapsed: #{elapsed}s"
    puts "Amount:      #{result.amount&.to_s('F')}"
    puts "Occurred at: #{result.occurred_at&.iso8601}"
    puts "Description: #{result.description}"
    puts "Confidence:  #{result.confidence}"
    puts "Metadata:    #{result.metadata.inspect}"
    puts "---"
    puts "Raw text:"
    puts result.raw_text
  end
end
