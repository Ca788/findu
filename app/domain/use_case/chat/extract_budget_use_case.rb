# frozen_string_literal: true

class UseCase::Chat::ExtractBudgetUseCase
  include Llm::ResponseParsing

  Result = Struct.new(:budget, :confidence, keyword_init: true)

  DEFAULT_MODEL = "gemini-2.5-flash"

  # @param [String]
  # @param [Llm::Prompts::BudgetPromptBuilder]
  def initialize(model: ENV.fetch("CHAT_BUDGET_MODEL", DEFAULT_MODEL),
                 prompt_builder: Llm::Prompts::BudgetPromptBuilder.new)
    @model          = model
    @prompt_builder = prompt_builder
  end

  # @param [User]
  # @param [String]
  # @return [Result]
  def call(user:, text:)
    data = llm_extract(
      text:           text,
      schema:         Llm::Schemas::BudgetSchema,
      model:          @model,
      prompt_builder: @prompt_builder
    )

    return Result.new(budget: nil, confidence: 0.0) if data["limit_amount"].blank?

    attributes = {
      period_type:  data["period_type"].presence || "monthly",
      period_start: parse_date(data["period_start"]) || Date.current.beginning_of_month,
      period_end:   parse_date(data["period_end"])   || Date.current.end_of_month,
      limit_amount: parse_decimal(data["limit_amount"])
    }

    budget = UseCase::Financial::Budget::CreateBudgetUseCase.new.call(
      user:       user,
      attributes: attributes
    )

    Result.new(budget: budget, confidence: data["confidence"].to_f)
  end
end
