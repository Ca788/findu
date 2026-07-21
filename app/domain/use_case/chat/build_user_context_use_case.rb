# frozen_string_literal: true

class UseCase::Chat::BuildUserContextUseCase
  Context = Struct.new(:statement, :budgets, :recent_transactions, :reference_date, keyword_init: true)

  RECENT_TRANSACTIONS_LIMIT = 10
  CACHE_TTL                 = 15.minutes

  def initialize(statement_use_case: UseCase::Financial::Statements::ShowMonthlyStatementUseCase.new,
                 budgets_use_case:   UseCase::Financial::Budget::ListCurrentBudgetsUseCase.new)
    @statement_use_case = statement_use_case
    @budgets_use_case   = budgets_use_case
  end

  # @param [User] user
  # @return [Context]
  def call(user:)
    today = Date.current

    Rails.cache.fetch(cache_key(user, today), expires_in: CACHE_TTL) do
      build_context(user, today)
    end
  end

  private

  def build_context(user, today)
    Context.new(
      statement:           @statement_use_case.call(user: user),
      budgets:             @budgets_use_case.call(user: user, date: today).budgets,
      recent_transactions: recent_transactions(user, today),
      reference_date:      today
    )
  end

  def cache_key(user, today)
    fingerprint = [
      Financial::Transaction.where(user_id: user.id).maximum(:updated_at),
      Financial::Budget.where(user_id: user.id).maximum(:updated_at),
      Financial::Category.where(user_id: user.id).maximum(:updated_at),
      Financial::RecurrenceRule.where(user_id: user.id).maximum(:updated_at),
      Financial::InstallmentPlan.where(user_id: user.id).maximum(:updated_at),
      today
    ].join(":")

    "chat:user_context:#{user.id}:#{Digest::MD5.hexdigest(fingerprint)}"
  end

  def recent_transactions(user, today)
    user.transactions
        .includes(:category)
        .in_competency(today)
        .order(status: :asc, paid_at: :desc, created_at: :desc)
        .limit(RECENT_TRANSACTIONS_LIMIT)
        .to_a
  end
end
