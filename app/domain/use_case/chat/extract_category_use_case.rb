# frozen_string_literal: true

class UseCase::Chat::ExtractCategoryUseCase
  include Llm::ResponseParsing

  Result = Struct.new(:category, :confidence, keyword_init: true)

  DEFAULT_MODEL = "gemini-2.5-flash"

  # @param [String]
  # @param [Llm::Prompts::CategoryPromptBuilder]
  # @param [UseCase::Financial::Category::FindOrCreateByNameUseCase]
  def initialize(model: ENV.fetch("CHAT_CATEGORY_MODEL", DEFAULT_MODEL),
                 prompt_builder: Llm::Prompts::CategoryPromptBuilder.new,
                 category_finder: UseCase::Financial::Category::FindOrCreateByNameUseCase.new)
    @model           = model
    @prompt_builder  = prompt_builder
    @category_finder = category_finder
  end

  # @param [User]
  # @param [String]
  # @return [Result]
  def call(user:, text:)
    data = llm_extract(
      text:           text,
      schema:         Llm::Schemas::CategorySchema,
      model:          @model,
      prompt_builder: @prompt_builder
    )

    name = data["name"].to_s.strip
    return Result.new(category: nil, confidence: 0.0) if name.blank?

    category = @category_finder.call(user: user, name: name)
    Result.new(category: category, confidence: data["confidence"].to_f)
  end
end
