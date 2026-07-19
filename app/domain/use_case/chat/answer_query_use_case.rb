# frozen_string_literal: true

class UseCase::Chat::AnswerQueryUseCase
  Result = Struct.new(:body, :payload, keyword_init: true)

  # @param [UseCase::Financial::Statements::ShowMonthlyStatementUseCase]
  # @param [UseCase::Financial::Budget::ListCurrentBudgetsUseCase]
  def initialize(statement_use_case: UseCase::Financial::Statements::ShowMonthlyStatementUseCase.new,
                 budgets_use_case:   UseCase::Financial::Budget::ListCurrentBudgetsUseCase.new)
    @statement_use_case = statement_use_case
    @budgets_use_case   = budgets_use_case
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
    statement = @statement_use_case.call(user: user)

    forecast = statement.forecast
    actual   = statement.actual

    body = "Extrato de #{statement.month}: " \
           "receitas previstas #{Formatters::Brl.call(forecast[:income])} " \
           "(pagas #{Formatters::Brl.call(actual[:income_paid])}), " \
           "despesas previstas #{Formatters::Brl.call(forecast[:expense])} " \
           "(pagas #{Formatters::Brl.call(actual[:expense_paid])}), " \
           "saldo previsto #{Formatters::Brl.call(forecast[:balance])} " \
           "(realizado #{Formatters::Brl.call(actual[:balance])}). " \
           "#{statement.counts[:pending]} pendente(s), #{statement.counts[:paid]} paga(s)."

    Result.new(
      body: body,
      payload: {
        month:    statement.month,
        forecast: forecast,
        actual:   actual,
        counts:   statement.counts
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
