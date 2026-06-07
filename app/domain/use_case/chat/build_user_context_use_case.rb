# frozen_string_literal: true

class UseCase::Chat::BuildUserContextUseCase
  Context = Struct.new(:summary, :budgets, :recent_transactions, :reference_date, keyword_init: true)

  RECENT_TRANSACTIONS_LIMIT = 10
  CACHE_TTL                 = 5.minutes

  def initialize(summary_use_case: UseCase::Financial::SummaryUseCase.new,
                 budgets_use_case: UseCase::Financial::Budget::ListCurrentBudgetsUseCase.new)
    @summary_use_case = summary_use_case
    @budgets_use_case = budgets_use_case
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

  # @param [User] user
  # @param [Date] today
  # @return [Context]
  def build_context(user, today)
    Context.new(
      summary:             @summary_use_case.call(user: user),
      budgets:             @budgets_use_case.call(user: user, date: today).budgets,
      recent_transactions: recent_transactions(user),
      reference_date:      today
    )
  end

  # @param [User] user
  # @param [Date] today
  # @return [String] cache key fingerprinted on the user's financial data so it
  #   self-invalidates on any change without write-side hooks
  def cache_key(user, today)
    fingerprint = [
      Financial::Transaction.where(user_id: user.id).maximum(:updated_at),
      Financial::Budget.where(user_id: user.id).maximum(:updated_at),
      Financial::Category.where(user_id: user.id).maximum(:updated_at),
      today
    ].join(":")

    "chat:user_context:#{user.id}:#{Digest::MD5.hexdigest(fingerprint)}"
  end

  # @param [User] user
  # @return [Array<Financial::Transaction>]
  def recent_transactions(user)
    user.transactions
        .includes(:category)
        .order(occurred_at: :desc, created_at: :desc)
        .limit(RECENT_TRANSACTIONS_LIMIT)
        .to_a
  end
end
