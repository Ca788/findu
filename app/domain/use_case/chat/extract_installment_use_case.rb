# frozen_string_literal: true

class UseCase::Chat::ExtractInstallmentUseCase
  include Llm::ResponseParsing

  Result = Struct.new(:transaction, :installment, :confidence, keyword_init: true)

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
    return Result.new(transaction: nil, installment: nil, confidence: 0.0) if total_amount.blank? || total_installments.zero?

    monthly_amount = parse_decimal(data["monthly_amount"]) || (total_amount / total_installments)
    started_at     = parse_time(data["started_at"]) || Time.current

    transaction = UseCase::Financial::Transaction::CreateTransactionUseCase.new.call(
      user:             user,
      amount:           monthly_amount,
      transaction_type: "expense",
      description:      data["description"].presence,
      occurred_at:      started_at,
      metadata:         { source: "chat_installment" }
    )

    installment = UseCase::Financial::Installment::CreateInstallmentUseCase.new.call(
      user:           user,
      transaction_id: transaction.id,
      attributes: {
        total_amount:        total_amount,
        total_installments:  total_installments,
        current_installment: 1,
        monthly_amount:      monthly_amount,
        started_at:          started_at
      }
    )

    Result.new(transaction: transaction, installment: installment, confidence: data["confidence"].to_f)
  end
end
