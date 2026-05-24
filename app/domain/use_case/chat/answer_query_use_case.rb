# frozen_string_literal: true

class UseCase::Chat::AnswerQueryUseCase
  Result = Struct.new(:body, :payload, keyword_init: true)

  # @param [UseCase::Financial::SummaryUseCase]
  # @param [UseCase::Financial::Budget::ListCurrentBudgetsUseCase]
  def initialize(summary_use_case: UseCase::Financial::SummaryUseCase.new,
                 budgets_use_case: UseCase::Financial::Budget::ListCurrentBudgetsUseCase.new)
    @summary_use_case = summary_use_case
    @budgets_use_case = budgets_use_case
  end

  # @param [User]
  # @param [String]
  # @return [Result]
  def call(user:, intent:)
    case intent
    when "query_balance" then balance_reply(user)
    when "query_budget"  then budget_reply(user)
    else
      Result.new(body: "Não entendi sua pergunta.", payload: {})
    end
  end

  private

  def balance_reply(user)
    summary = @summary_use_case.call(user: user)

    income  = summary.by_type["income"] || 0
    expense = summary.by_type["expense"] || 0
    net     = income - expense

    body = "Resumo de #{summary.from.strftime('%d/%m')} a #{summary.to.strftime('%d/%m')}: " \
           "receitas #{Formatters::Brl.call(income)}, despesas #{Formatters::Brl.call(expense)}, " \
           "saldo #{Formatters::Brl.call(net)} (#{summary.transaction_count} transações)."

    Result.new(
      body: body,
      payload: {
        from:              summary.from,
        to:                summary.to,
        total_amount:      summary.total_amount,
        transaction_count: summary.transaction_count,
        by_type:           summary.by_type
      }
    )
  end

  def budget_reply(user)
    listing = @budgets_use_case.call(user: user)
    budgets = listing.budgets

    return Result.new(body: "Você não tem nenhum orçamento ativo para hoje.", payload: { budgets: [] }) if budgets.empty?

    lines = budgets.map do |budget|
      "#{budget.period_type.capitalize}: gasto #{Formatters::Brl.call(budget.spent_amount)} de #{Formatters::Brl.call(budget.limit_amount)} " \
        "(#{budget.usage_percent}%), resta #{Formatters::Brl.call(budget.remaining)}."
    end

    Result.new(
      body: lines.join("\n"),
      payload: {
        reference_date: listing.reference_date,
        budgets:        budgets.map { |b| budget_summary(b) }
      }
    )
  end

  def budget_summary(budget)
    {
      id:            budget.id,
      period_type:   budget.period_type,
      period_start:  budget.period_start,
      period_end:    budget.period_end,
      limit_amount:  budget.limit_amount,
      spent_amount:  budget.spent_amount,
      remaining:     budget.remaining,
      usage_percent: budget.usage_percent
    }
  end
end
