# frozen_string_literal: true

class UseCase::Chat::ExtractInstallmentUseCase
  include Llm::ResponseParsing

  Result = Struct.new(:plan, :confidence, keyword_init: true)

  # @param [Array<String>]
  # @param [Llm::Prompts::InstallmentPromptBuilder]
  def initialize(models: Llm::Models.chain("CHAT_INSTALLMENT_MODEL"),
                 prompt_builder: Llm::Prompts::InstallmentPromptBuilder.new)
    @models         = models
    @prompt_builder = prompt_builder
  end

  # @param [User]
  # @param [String]
  # @return [Result]
  def call(user:, text:)
    data = llm_extract(
      text:           text,
      schema:         Llm::Schemas::InstallmentSchema,
      models:         @models,
      prompt_builder: @prompt_builder
    )

    total_amount       = parse_decimal(data["total_amount"])
    total_installments = data["total_installments"].to_i
    return Result.new(plan: nil, confidence: 0.0) if total_amount.blank? || total_installments.zero?

    monthly_amount = parse_decimal(data["monthly_amount"]) || (total_amount / total_installments)
    started_at     = parse_time(data["started_at"]) || Time.current

    plan = UseCase::Financial::InstallmentPlan::CreateInstallmentPlanUseCase.new.call(
      user: user,
      attributes: {
        description:        data["description"].presence,
        transaction_type:   "expense",
        total_installments: total_installments,
        monthly_amount:     monthly_amount,
        total_amount:       total_amount,
        first_competency:   started_at.to_date.beginning_of_month
      }
    )

    Result.new(plan: plan, confidence: data["confidence"].to_f)
  end
end
