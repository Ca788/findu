# frozen_string_literal: true

module Api
  module V1
    module Financial
      class BudgetsController < Api::BaseController
        def index
          budgets = @user.budgets
                         .for_period_type(params[:period_type])
                         .order(period_start: :desc)
                         .page(page_param)
                         .per(per_page_param)

          render json: ApiResponseSerializer.render_data_array(
            budgets,
            serializer: V1::Financial::BudgetSerializer,
            serializer_view: :default,
            pagination: pagination_for(budgets)
          ), status: :ok
        end

        def show
          budget = @user.budgets.find(params[:id])

          render json: ApiResponseSerializer.render(
            budget,
            serializer: V1::Financial::BudgetSerializer,
            serializer_view: :extended
          ), status: :ok
        end

        def current
          date = parse_date(params[:date]) || Date.current
          budgets = @user.budgets
                         .covering(date)
                         .order(:period_start)

          render json: ApiResponseSerializer.render_data_array(
            budgets,
            serializer: V1::Financial::BudgetSerializer,
            serializer_view: :extended,
            metadata: { reference_date: date }
          ), status: :ok
        end

        def create
          budget = @user.budgets.create!(budget_params)

          render json: ApiResponseSerializer.render(
            budget,
            serializer: V1::Financial::BudgetSerializer,
            serializer_view: :extended,
            message: "Budget created successfully."
          ), status: :created
        end

        def update
          budget = @user.budgets.find(params[:id])
          budget.update!(budget_params)

          render json: ApiResponseSerializer.render(
            budget,
            serializer: V1::Financial::BudgetSerializer,
            serializer_view: :extended,
            message: "Budget updated successfully."
          ), status: :ok
        end

        def destroy
          @user.budgets.find(params[:id]).destroy!

          render json: ApiResponseSerializer.render(
            {},
            message: "Budget deleted successfully."
          ), status: :ok
        end

        private

        def budget_params
          params.require(:budget).permit(*::Financial::Budget::PERMITTED_ATTRIBUTES)
        end

        def parse_date(value)
          return nil if value.blank?
          Date.parse(value.to_s)
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
