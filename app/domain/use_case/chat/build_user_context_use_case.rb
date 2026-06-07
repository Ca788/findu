# frozen_string_literal: true

class UseCase::Chat::BuildUserContextUseCase
  Context = Struct.new(:summary, :budgets, :recent_transactions, :reference_date, keyword_init: true)

  RECENT_TRANSACTIONS_LIMIT = 10

  def initialize(summary_use_case: UseCase::Financial::SummaryUseCase.new,
                 budgets_use_case: UseCase::Financial::Budget::ListCurrentBudgetsUseCase.new)
    @summary_use_case = summary_use_case
    @budgets_use_case = budgets_use_case
  end

  # @param [User] user
  # @return [Context]
  def call(user:)
    today = Date.current

    Context.new(
      summary:             @summary_use_case.call(user: user),
      budgets:             @budgets_use_case.call(user: user, date: today).budgets,
      recent_transactions: recent_transactions(user),
      reference_date:      today
    )
  end

  private

  def recent_transactions(user)
    user.transactions
        .includes(:category)
        .order(occurred_at: :desc, created_at: :desc)
        .limit(RECENT_TRANSACTIONS_LIMIT)
        .to_a
  end
end
