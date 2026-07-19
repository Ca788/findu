# frozen_string_literal: true

module Api
  module V1
    module Financial
      class InstallmentPlansController < Api::BaseController
        def index
          plans = @user.installment_plans
                       .includes(:category)
                       .order(created_at: :desc)
                       .page(page_param)
                       .per(per_page_param)

          render json: ApiResponseSerializer.render_data_array(
            plans,
            serializer:      ::V1::Financial::InstallmentPlanSerializer,
            serializer_view: :default,
            pagination:      pagination_for(plans)
          ), status: :ok
        end

        def show
          plan = @user.installment_plans.find(params[:id])

          render json: ApiResponseSerializer.render(
            plan,
            serializer:      ::V1::Financial::InstallmentPlanSerializer,
            serializer_view: :extended
          ), status: :ok
        end

        def create
          plan = UseCase::Financial::InstallmentPlan::CreateInstallmentPlanUseCase.new.call(
            user:       @user,
            attributes: plan_params.to_h
          )

          render json: ApiResponseSerializer.render(
            plan,
            serializer:      ::V1::Financial::InstallmentPlanSerializer,
            serializer_view: :extended,
            message:         "Installment plan created."
          ), status: :created
        end

        def update
          plan = UseCase::Financial::InstallmentPlan::UpdateInstallmentPlanUseCase.new.call(
            user:       @user,
            id:         params[:id],
            attributes: plan_params.to_h
          )

          render json: ApiResponseSerializer.render(
            plan,
            serializer:      ::V1::Financial::InstallmentPlanSerializer,
            serializer_view: :extended,
            message:         "Installment plan updated."
          ), status: :ok
        end

        def destroy
          UseCase::Financial::InstallmentPlan::CancelInstallmentPlanUseCase.new.call(
            user: @user,
            id:   params[:id]
          )

          render json: ApiResponseSerializer.render({}, message: "Installment plan canceled."), status: :ok
        end

        private

        def plan_params
          params.require(:installment_plan).permit(*::Financial::InstallmentPlan::PERMITTED_ATTRIBUTES)
        end
      end
    end
  end
end
