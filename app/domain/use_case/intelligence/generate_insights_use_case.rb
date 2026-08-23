# frozen_string_literal: true

class UseCase::Intelligence::GenerateInsightsUseCase
  include Llm::ResponseParsing

  EMPTY_PAYLOAD = { "insights" => [] }.freeze

  # @param [UseCase::Chat::BuildUserContextUseCase]
  # @param [UseCase::Financial::Category::ListCategoryTotalsUseCase]
  # @param [Llm::Prompts::InsightPromptBuilder]
  # @param [Array<String>]
  def initialize(context_builder: UseCase::Chat::BuildUserContextUseCase.new,
                 totals_use_case: UseCase::Financial::Category::ListCategoryTotalsUseCase.new,
                 prompt_builder: Llm::Prompts::InsightPromptBuilder.new,
                 models: Llm::Models.chain("INSIGHTS_MODEL"))
    @context_builder = context_builder
    @totals_use_case = totals_use_case
    @prompt_builder  = prompt_builder
    @models          = models
  end

  # @param [User]
  # @param [Date, String, nil]
  # @return [Array<Intelligence::Insight>]
  def call(user:, month: nil)
    period  = (Support::DateParser.parse_month(month) || Date.current.beginning_of_month).strftime("%Y-%m")
    context = @context_builder.call(user: user)
    totals  = @totals_use_case.call(user: user, from: period, to: period)

    entries = request_insights(context, totals)
    return [] if entries.blank?

    persist(user, period, entries)
  end

  private

  # @return [Array<Hash>]
  def request_insights(context, totals)
    prompt   = @prompt_builder.call(context: context, category_totals: totals)
    response = Llm::ModelFallback.with_fallback(@models) do |model|
      Llm::GeminiChat.for(model).with_schema(Llm::Schemas::InsightSchema).ask(prompt)
    end

    parse_payload(response.content, fallback: EMPTY_PAYLOAD)["insights"].to_a
  rescue RubyLLM::Error => e
    Rails.logger.error("[GenerateInsightsUseCase] #{e.class}: #{e.message}")
    []
  end

  # @return [Array<Intelligence::Insight>]
  def persist(user, period, entries)
    ::Intelligence::Insight.transaction do
      user.insights
          .by_reference_type(::Intelligence::Insight::REFERENCE_MONTHLY_STATEMENT)
          .for_period(period)
          .destroy_all

      entries.filter_map { |entry| build_insight(user, period, entry) }
    end
  end

  # @return [Intelligence::Insight, nil]
  def build_insight(user, period, entry)
    content = entry["content"].to_s.strip
    return nil if content.blank?

    user.insights.create!(
      reference_type: ::Intelligence::Insight::REFERENCE_MONTHLY_STATEMENT,
      content:        content,
      severity:       normalize_severity(entry["severity"]),
      metadata:       { "period" => period, "category_name" => entry["category_name"] }.compact
    )
  end

  # @return [String]
  def normalize_severity(value)
    severity = value.to_s.downcase
    ::Intelligence::Insight::SEVERITIES.include?(severity) ? severity : ::Intelligence::Insight::DEFAULT_SEVERITY
  end
end
