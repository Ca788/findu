# frozen_string_literal: true

module Api
  module V1
    module Financial
      class RecurrenceRulesController < Api::BaseController
        def index
          rules = @user.recurrence_rules
                       .includes(:category)
                       .order(created_at: :desc)
                       .page(page_param)
                       .per(per_page_param)

          render json: ApiResponseSerializer.render_data_array(
            rules,
            serializer:      ::V1::Financial::RecurrenceRuleSerializer,
            serializer_view: :default,
            pagination:      pagination_for(rules)
          ), status: :ok
        end

        def show
          rule = @user.recurrence_rules.find(params[:id])

          render json: ApiResponseSerializer.render(
            rule,
            serializer:      ::V1::Financial::RecurrenceRuleSerializer,
            serializer_view: :extended
          ), status: :ok
        end

        def create
          rule = UseCase::Financial::Recurrence::CreateRecurrenceRuleUseCase.new.call(
            user:       @user,
            attributes: rule_params.to_h
          )

          render json: ApiResponseSerializer.render(
            rule,
            serializer:      ::V1::Financial::RecurrenceRuleSerializer,
            serializer_view: :extended,
            message:         "Recurrence created."
          ), status: :created
        end

        def update
          rule = UseCase::Financial::Recurrence::UpdateRecurrenceRuleUseCase.new.call(
            user:       @user,
            id:         params[:id],
            attributes: rule_params.to_h
          )

          render json: ApiResponseSerializer.render(
            rule,
            serializer:      ::V1::Financial::RecurrenceRuleSerializer,
            serializer_view: :extended,
            message:         "Recurrence updated."
          ), status: :ok
        end

        def destroy
          UseCase::Financial::Recurrence::CancelRecurrenceRuleUseCase.new.call(
            user: @user,
            id:   params[:id]
          )

          render json: ApiResponseSerializer.render({}, message: "Recurrence canceled."), status: :ok
        end

        private

        def rule_params
          params.require(:recurrence_rule).permit(*::Financial::RecurrenceRule::PERMITTED_ATTRIBUTES)
        end
      end
    end
  end
end
