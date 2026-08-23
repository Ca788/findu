# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Intelligence::GenerateInsightsUseCase do
  subject(:use_case) do
    described_class.new(
      context_builder: context_builder,
      totals_use_case: totals_use_case,
      models:          ["gemini-test"]
    )
  end

  let(:user)  { create(:user) }
  let(:month) { "2026-08" }

  let(:statement) do
    UseCase::Financial::Statements::ShowMonthlyStatementUseCase::Statement.new(
      month:               month,
      forecast:            { income: 3000, expense: 800, balance: 2200 },
      actual:              { income_paid: 3000, expense_paid: 500, balance: 2500 },
      counts:              { pending: 1, paid: 2, total: 3 },
      entries:             [],
      installments_active: [],
      recurrences_active:  [],
      by_category:         []
    )
  end

  let(:context) do
    UseCase::Chat::BuildUserContextUseCase::Context.new(
      statement:           statement,
      budgets:             [],
      recent_transactions: [],
      reference_date:      Date.new(2026, 8, 15)
    )
  end

  let(:context_builder) { instance_double(UseCase::Chat::BuildUserContextUseCase, call: context) }
  let(:totals_use_case) { instance_double(UseCase::Financial::Category::ListCategoryTotalsUseCase, call: []) }

  let(:payload) do
    {
      "insights" => [
        { "content" => "Suas despesas caíram 20% neste mês.", "severity" => "info", "category_name" => "Groceries" },
        { "content" => "Você tem R$300,00 pendentes.", "severity" => "warning" }
      ]
    }
  end

  let(:chat) { instance_double("RubyLLM::Chat") }

  before do
    allow(Llm::GeminiChat).to receive(:for).and_return(chat)
    allow(chat).to receive(:with_schema).and_return(chat)
    allow(chat).to receive(:ask).and_return(instance_double("RubyLLM::Message", content: payload))
  end

  describe "#call" do
    it "persists one insight per entry returned by the model" do
      expect { use_case.call(user: user, month: month) }.to change(user.insights, :count).by(2)
    end

    it "stores content, severity and period metadata" do
      insight = use_case.call(user: user, month: month).first

      expect(insight).to have_attributes(
        user_id:        user.id,
        reference_type: Intelligence::Insight::REFERENCE_MONTHLY_STATEMENT,
        content:        "Suas despesas caíram 20% neste mês.",
        severity:       "info"
      )
      expect(insight.metadata).to eq("period" => month, "category_name" => "Groceries")
    end

    it "falls back to the default severity when the model returns an unknown value" do
      payload["insights"] = [{ "content" => "Algo aconteceu.", "severity" => "urgentissimo" }]

      expect(use_case.call(user: user, month: month).first.severity)
        .to eq(Intelligence::Insight::DEFAULT_SEVERITY)
    end

    it "skips entries without content" do
      payload["insights"] = [{ "content" => "  ", "severity" => "info" }]

      expect { use_case.call(user: user, month: month) }.not_to change(user.insights, :count)
    end

    it "replaces the previous batch for the same period instead of duplicating" do
      use_case.call(user: user, month: month)

      expect { use_case.call(user: user, month: month) }.not_to change(user.insights, :count)
    end

    it "keeps insights generated for other periods" do
      use_case.call(user: user, month: "2026-07")

      expect { use_case.call(user: user, month: month) }.to change(user.insights, :count).by(2)
    end

    it "returns an empty array and persists nothing when the model fails" do
      allow(chat).to receive(:ask).and_raise(RubyLLM::Error.new(nil, "boom"))

      expect(use_case.call(user: user, month: month)).to eq([])
      expect(user.insights.count).to eq(0)
    end

    it "defaults to the current month when none is given" do
      travel_to(Time.zone.local(2026, 8, 15, 12, 0)) do
        expect(use_case.call(user: user).first.metadata["period"]).to eq("2026-08")
      end
    end
  end
end
