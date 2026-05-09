# frozen_string_literal: true

class UseCase::Financial::Budget::ListCurrentBudgetsUseCase
  Result = Struct.new(:budgets, :reference_date, keyword_init: true)

  # @param [User] user
  # @param [Date, String, nil] date
  # @return [Result]
  def call(user:, date: nil)
    reference_date = Support::DateParser.parse(date) || Date.current

    Result.new(
      budgets:        user.budgets.covering(reference_date).order(:period_start),
      reference_date: reference_date
    )
  end
end
