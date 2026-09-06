#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"

ROOT = Pathname.new(File.expand_path("..", __dir__))
USE_CASE_GLOB = "app/domain/use_case/**/*_use_case.rb"
SPEC_GLOB = "spec/domain/use_case/**/*_use_case_spec.rb"
RSPEC_JSON = ROOT.join("tmp/rspec.json")
REPORT_PATH = ROOT.join("tmp/use_case_health.md")

UseCase = Struct.new(:path, :context, :name, :spec_path, :covered, keyword_init: true)
Example = Struct.new(:file_path, :description, :status, :exception, keyword_init: true)

def relative(path)
  Pathname.new(path).relative_path_from(ROOT).to_s
end

def context_for(rel_path)
  parts = rel_path.delete_prefix("app/domain/use_case/").split("/")
  parts.length > 1 ? parts.first : "shared"
end

def spec_for(use_case_rel)
  "spec/domain/use_case/#{use_case_rel.delete_prefix("app/domain/use_case/").sub(/\.rb\z/, "")}_spec.rb"
end

def load_use_cases
  Dir[ROOT.join(USE_CASE_GLOB)].sort.map do |absolute|
    rel = relative(absolute)
    spec = spec_for(rel)
    UseCase.new(
      path:      rel,
      context:   context_for(rel),
      name:      File.basename(rel, ".rb"),
      spec_path: spec,
      covered:   File.exist?(ROOT.join(spec))
    )
  end
end

def load_examples
  return [] unless RSPEC_JSON.exist?

  payload = JSON.parse(RSPEC_JSON.read)
  Array(payload["examples"]).filter_map do |example|
    file = example["file_path"].to_s.sub(%r{\A\./}, "")
    next unless file.start_with?("spec/domain/use_case/")

    exception = example.dig("exception", "message")
    Example.new(
      file_path:   file,
      description: example["full_description"].to_s,
      status:      example["status"].to_s,
      exception:   exception
    )
  end
end

def status_icon(use_case, examples)
  scoped = examples.select { |example| example.file_path == use_case.spec_path }
  return "🔴 sem spec" unless use_case.covered
  return "🔴 falhou" if scoped.any? { |example| example.status == "failed" }
  return "🟡 pendente" if scoped.any? { |example| example.status == "pending" }
  return "🟢 ok" if scoped.any? { |example| example.status == "passed" }

  "🟡 spec sem exemplos"
end

def percent(part, total)
  return "0%" if total.zero?

  "#{((part.to_f / total) * 100).round}%"
end

def write_report(use_cases, examples)
  covered = use_cases.count(&:covered)
  missing = use_cases.reject(&:covered)
  failed = examples.select { |example| example.status == "failed" }
  passed = examples.count { |example| example.status == "passed" }
  pending = examples.count { |example| example.status == "pending" }

  lines = []
  lines << "# Saúde dos UseCases"
  lines << ""
  lines << "Regra de negócio do Findu vive em `app/domain/use_case`. Este relatório mede cobertura e resultado dos specs desse recorte."
  lines << ""
  lines << "## Resumo"
  lines << ""
  lines << "| Métrica | Valor |"
  lines << "|---|---|"
  lines << "| UseCases no domínio | #{use_cases.size} |"
  lines << "| Com spec | #{covered} (#{percent(covered, use_cases.size)}) |"
  lines << "| Sem spec | #{missing.size} |"
  lines << "| Exemplos RSpec | #{examples.size} |"
  lines << "| Passou | #{passed} |"
  lines << "| Falhou | #{failed.size} |"
  lines << "| Pendente | #{pending} |"
  lines << ""

  lines << "## Por contexto"
  lines << ""
  lines << "| Contexto | UseCases | Com spec | Exemplos | Falhas | Saúde |"
  lines << "|---|---:|---:|---:|---:|---|"

  use_cases.group_by(&:context).sort.each do |context, group|
    scoped_examples = examples.select do |example|
      group.any? { |use_case| example.file_path == use_case.spec_path }
    end
    fails = scoped_examples.count { |example| example.status == "failed" }
    covered_count = group.count(&:covered)
    health =
      if fails.positive?
        "🔴"
      elsif covered_count == group.size
        "🟢"
      elsif covered_count.positive?
        "🟡"
      else
        "🔴"
      end

    lines << "| #{context} | #{group.size} | #{covered_count} | #{scoped_examples.size} | #{fails} | #{health} |"
  end

  lines << ""
  lines << "## Inventário"
  lines << ""
  lines << "| UseCase | Spec | Status |"
  lines << "|---|---|---|"
  use_cases.each do |use_case|
    spec_label = use_case.covered ? "`#{use_case.spec_path}`" : "—"
    lines << "| `#{use_case.name}` | #{spec_label} | #{status_icon(use_case, examples)} |"
  end

  if missing.any?
    lines << ""
    lines << "## Sem cobertura"
    lines << ""
    missing.each { |use_case| lines << "- `#{use_case.path}`" }
  end

  if failed.any?
    lines << ""
    lines << "## Falhas"
    lines << ""
    failed.each do |example|
      lines << "- **#{example.description}** (`#{example.file_path}`)"
      lines << "  - #{example.exception}" if example.exception
    end
  end

  lines << ""
  report = lines.join("\n")
  REPORT_PATH.dirname.mkpath
  REPORT_PATH.write(report)
  report
end

use_cases = load_use_cases
examples = load_examples
report = write_report(use_cases, examples)

summary = ENV["GITHUB_STEP_SUMMARY"]
File.write(summary, report, mode: "a") if summary && !summary.empty?

puts report
puts ""
puts "Report written to #{REPORT_PATH}"
