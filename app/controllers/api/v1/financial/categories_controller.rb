# frozen_string_literal: true

module Api
  module V1
    module Financial
      class CategoriesController < Api::BaseController
        include ExceptionHandler

        def index
          categories = @user.categories
                            .order(name: :asc)
                            .page(page_param)
                            .per(per_page_param)

          render json: ApiResponseSerializer.render_data_array(
            categories,
            serializer: V1::Financial::CategorySerializer,
            pagination: pagination_for(categories)
          ), status: :ok
        end

        def show
          category = @user.categories.find(params[:id])

          render json: ApiResponseSerializer.render(
            category,
            serializer: V1::Financial::CategorySerializer,
          ), status: :ok
        end

        def create
          category = UseCase::Financial::Category::CreateCategoryUseCase.new.call(
            user: @user,
            name: category_params[:name]
          )

          render json: ApiResponseSerializer.render(
            category,
            serializer: V1::Financial::CategorySerializer,
            message: "Category created successfully."
          ), status: :created
        end

        def update
          category = UseCase::Financial::Category::UpdateCategoryUseCase.new.call(
            user: @user,
            id: params[:id],
            attributes: category_params.to_h.symbolize_keys
          )

          render json: ApiResponseSerializer.render(
            category,
            serializer: V1::Financial::CategorySerializer,
            message: "Category updated successfully."
          ), status: :ok
        end

        def destroy
          UseCase::Financial::Category::DestroyCategoryUseCase.new.call(
            user: @user,
            id: params[:id]
          )

          render json: ApiResponseSerializer.render(
            {},
            message: "Category deleted successfully."
          ), status: :ok
        end

        private

        def category_params
          params.require(:category).permit(:name)
        end
      end
    end
  end
end
