# Contrato de Resposta da API — Padrão de Retorno

> Documento **isolado e autocontido** do padrão de envelope de resposta da Findu API,
> com o **código real** de todas as partes que o compõem.
> Serve como referência para replicar exatamente o mesmo padrão de retorno em outros
> projetos. Para a referência endpoint a endpoint, ver [`API.md`](./API.md).

---

## Sumário

- [Princípios](#princípios)
- [Anatomia do envelope](#anatomia-do-envelope)
  - [Sucesso — recurso único](#sucesso--recurso-único)
  - [Sucesso — coleção paginada](#sucesso--coleção-paginada)
  - [Sucesso — com metadata](#sucesso--com-metadata)
  - [Sucesso — sem corpo de dados](#sucesso--sem-corpo-de-dados)
  - [Erro — simples](#erro--simples)
  - [Erro — detalhado](#erro--detalhado)
- [Campos do envelope](#campos-do-envelope)
- [Contrato de paginação](#contrato-de-paginação)
- [Contrato de erro](#contrato-de-erro)
- [Convenções de serialização](#convenções-de-serialização)
- [Componentes — código real](#componentes--código-real)
  - [1. Serializer de envelope](#1-serializer-de-envelope-apiresponseserializer)
  - [2. Mapa de erros](#2-mapa-de-erros-errormapper)
  - [3. Tratamento de exceções](#3-tratamento-de-exceções-exceptionhandler)
  - [4. Parâmetros de paginação](#4-parâmetros-de-paginação-paginationparams)
  - [5. Controller base](#5-controller-base)
  - [6. Serializers de domínio](#6-serializers-de-domínio)
- [Uso real nos controllers](#uso-real-nos-controllers)
- [Schema (TypeScript)](#schema-typescript)
- [Cliente HTTP de referência](#cliente-http-de-referência)
- [Checklist de portabilidade](#checklist-de-portabilidade)

---

## Princípios

1. **Envelope único e previsível.** Toda resposta — sucesso ou erro — tem a mesma
   forma de topo. O cliente nunca adivinha o shape: olha `success` e segue.
2. **`success` é a fonte da verdade**, não o status HTTP. O HTTP continua semântico,
   mas o cliente decide o fluxo por `success`.
3. **Dados de domínio isolados em `data`.** Metadados de transporte (paginação,
   mensagens, códigos de erro) nunca se misturam com o payload.
4. **Erros estruturados e codificados.** Cada erro carrega um `errorCode` estável,
   desacoplado do HTTP, para tratamento programático.
5. **Campos opcionais são omitidos, não nulos.** Sem paginação, a chave `pagination`
   não aparece. Sem recurso, `data` não aparece.

---

## Anatomia do envelope

### Sucesso — recurso único

```json
{
  "success": true,
  "message": "Transaction created successfully.",
  "data": {
    "id": "1f2a...",
    "amount": "50.00",
    "transaction_type": "expense"
  }
}
```

### Sucesso — coleção paginada

```json
{
  "success": true,
  "data": [
    { "id": "...", "name": "mercado" },
    { "id": "...", "name": "transporte" }
  ],
  "pagination": {
    "currentPage": 1,
    "nextPage": 2,
    "prevPage": null,
    "totalPages": 5,
    "totalCount": 47
  }
}
```

### Sucesso — com metadata

`metadata` carrega contexto extra que não é dado de domínio nem paginação
(ex.: a data de referência de um filtro, o intervalo agregado de um resumo).

```json
{
  "success": true,
  "data": [ { "...": "..." } ],
  "metadata": { "reference_date": "2026-05-24" }
}
```

### Sucesso — sem corpo de dados

`DELETE`, `logout`, etc. retornam só a confirmação. `data` é **omitido**.

```json
{
  "success": true,
  "message": "Transaction deleted successfully."
}
```

### Erro — simples

Caminho padrão: `message` + `errorCode`.

```json
{
  "success": false,
  "message": "Validation failed",
  "errorCode": 1003
}
```

### Erro — detalhado

Objeto `error` com `code`/`title`/`description` (usado, por exemplo, na falha de
assinatura do webhook inbound). `description` nulo é omitido (`.compact`).

```json
{
  "success": false,
  "error": {
    "code": 1001,
    "title": "Invalid credentials"
  }
}
```

---

## Campos do envelope

| Campo | Tipo | Presença | Descrição |
|---|---|---|---|
| `success` | `boolean` | **sempre** | `true` em 2xx; `false` em erro. Fonte da verdade. |
| `data` | `object \| array` | quando há recurso | Payload de domínio. Objeto p/ recurso único, array p/ coleção. Omitido sem corpo. |
| `message` | `string` | opcional | Mensagem legível (confirmação ou descrição do erro). |
| `errorCode` | `number` | só em erro simples | Código estável, desacoplado do HTTP. |
| `pagination` | `object` | só em coleção paginada | Metadados de paginação. |
| `metadata` | `object` | opcional | Contexto extra de transporte. |
| `filterOptions` | `object` | opcional | Opções de filtro disponíveis para a listagem. |
| `error` | `object` | só em erro detalhado | `{ code, title, description }`. Alternativa a `message`/`errorCode`. |

> **Regra de ouro:** campos opcionais ausentes são **omitidos**, nunca `null`.

---

## Contrato de paginação

Entrada (query string):

| Query param | Tipo | Default | Limite |
|---|---|---|---|
| `page` | int | `1` | mínimo 1 |
| `perPage` (ou `per_page`) | int | `10` | `50` (clampado) |

Saneamento: `page < 1 → 1`; `perPage < 1 → default`; `perPage > 50 → 50`.

Saída em `pagination`:

| Campo | Tipo | Descrição |
|---|---|---|
| `currentPage` | `number` | Página atual. |
| `nextPage` | `number \| null` | Próxima, ou `null` na última. |
| `prevPage` | `number \| null` | Anterior, ou `null` na primeira. |
| `totalPages` | `number` | Total de páginas. |
| `totalCount` | `number` | Total de registros (não da página). |

---

## Contrato de erro

Erros centralizados num mapa (`ErrorMapper`): cada erro tem `code` (o `errorCode`)
e mensagem padrão. O `errorCode` é **estável e independente do HTTP** — HTTPs
diferentes podem compartilhar o mesmo código (ex.: `1003` cobre 422 e 409).

| `errorCode` | HTTP | Exceção de origem (Rails) | `message` |
|---|---|---|---|
| `500` | `500 Internal Server Error` | `StandardError` (fallback) | `Unknown Error` |
| `404` | `404 Not Found` | `ActiveRecord::RecordNotFound` | `<Modelo> not found` |
| `1001` | `401 Unauthorized` | Falha de auth / assinatura inválida | `Invalid credentials` |
| `1002` | `400 Bad Request` | `ActionController::ParameterMissing` | `Missing parameter: <param>` |
| `1003` | `422 Unprocessable Entity` | `ActiveRecord::RecordInvalid`, `ArgumentError` | erros do model |
| `1003` | `409 Conflict` | `ActiveRecord::RecordNotUnique` | `Record already exists` |

> Para validações, `message` traz a lista completa: `errors.full_messages.join(", ")`.
> Princípio de boundary: exceções são tratadas **apenas na borda HTTP** (concern no
> controller base). O domínio levanta exceções naturais; o boundary traduz.

---

## Convenções de serialização

- **Versionamento**: tudo sob `/api/v1/...`.
- **Content-Type**: `application/json` (exceto upload, `multipart/form-data`).
- **IDs**: UUID v4 (string).
- **Datas**: ISO-8601 em UTC.
- **Valores monetários**: decimal como **string** (`"50.00"`), sempre positivo; o
  tipo (`expense`/`income`) define a natureza.
- **Casing**:
  - Campos de **domínio** em `data` → **snake_case** (`transaction_type`, `occurred_at`).
  - Envelope de **transporte** → **camelCase** (`errorCode`, `currentPage`, `totalCount`).

---

## Componentes — código real

O padrão é composto por **6 peças**. Todas abaixo são o código real do projeto.

| # | Peça | Arquivo | Responsabilidade |
|---|---|---|---|
| 1 | `ApiResponseSerializer` | `app/serializers/api_response_serializer.rb` | Monta o envelope. |
| 2 | `ErrorMapper` | `app/controllers/error_mapper.rb` | Mapa central `errorCode → mensagem`. |
| 3 | `ExceptionHandler` | `app/controllers/concerns/exception_handler.rb` | Traduz exceções para o envelope de erro. |
| 4 | `PaginationParams` | `app/controllers/concerns/pagination_params.rb` | Sanitiza paginação e monta o bloco. |
| 5 | `Api::BaseController` | `app/controllers/api/base_controller.rb` | Cola tudo + auth. |
| 6 | Serializers de domínio | `app/serializers/v1/**` | Definem o conteúdo de `data` (views). |

### 1. Serializer de envelope (`ApiResponseSerializer`)

Coração do padrão. Usa **Blueprinter**. Campos opcionais entram por `if:` com base
nas `options` passadas no `render`. O bloco `data` delega para o serializer de
domínio quando há um (`options[:serializer]`).

```ruby
# frozen_string_literal: true

class ApiResponseSerializer < Blueprinter::Base
  DEFAULT_OPTIONS = { success: true }.freeze

  class << self
    def render_data_array(objects, options = {})
      render({ data_array: objects }, options)
    end

    def error(error_obj, options = {})
      render({}, { success: false, error: error_obj }.merge(options))
    end

    def when_option(key)
      ->(_field_name, _object, options) { options[key].present? }
    end
  end

  field :success do |_object, options|
    options.fetch(:success, DEFAULT_OPTIONS[:success])
  end

  field(:message,       if: when_option(:message))       { |_o, opts| opts[:message] }
  field(:errorCode,     if: when_option(:error_code))    { |_o, opts| opts[:error_code] }
  field(:pagination,    if: when_option(:pagination))    { |_o, opts| opts[:pagination] }
  field(:filterOptions, if: when_option(:filterOptions)) { |_o, opts| opts[:filterOptions] }
  field(:metadata,      if: when_option(:metadata))      { |_o, opts| opts[:metadata] }

  field :error, if: when_option(:error) do |_object, options|
    err = options[:error]
    {
      code: err.code,
      title: err.title,
      description: err.description
    }.compact
  end

  field :data, if: ->(_field_name, object, _options) { object.present? } do |object, options|
    object = object[:data_array] if object.is_a?(Hash) && object.key?(:data_array)

    if options[:serializer].present?
      options[:serializer].render_as_hash(
        object,
        options.merge(view: options[:serializer_view])
      )
    else
      object
    end
  end
end
```

**Pontos de design:**
- `render_data_array` empacota a coleção em `{ data_array: objects }` para o bloco
  `data` saber que é array (desempacotado lá dentro). Necessário porque a coleção
  pode ser uma relação paginada (Kaminari).
- `error` (classe) recebe um objeto com `code`/`title`/`description` (ver `ErrorMapper`).
- `error_code` vira o campo `errorCode` (camelCase) na saída.

### 2. Mapa de erros (`ErrorMapper`)

Fonte única dos códigos. Cada `Error` expõe `code`, `title` e `description` —
exatamente o que o bloco `error` do serializer consome.

```ruby
# frozen_string_literal: true

module ErrorMapper
  class Error
    attr_reader :code, :message

    def initialize(code, message)
      @code = code
      @message = message
    end

    def title
      @message
    end

    def description
      nil
    end
  end

  ERRORS = {
    unknown_error: Error.new(500, "Unknown Error"),
    record_not_found: Error.new(404, "Record Not Found"),
    record_invalid: Error.new(1003, "Validation failed"),
    unauthorized: Error.new(1001, "Invalid credentials"),
    missing_parameter: Error.new(1002, "Missing parameter")
  }.freeze

  ERRORS.each do |key, error|
    define_singleton_method(key) { error }
  end

  def self.unknown_error
    Error.new(500, "Unknown Error")
  end

  # @param [String, nil] model_name eg. "Financial::Transaction"
  # @return [String]
  def self.record_not_found_message_for(model_name)
    return record_not_found.message if model_name.blank?

    "#{model_name.demodulize.titleize} not found"
  end
end
```

### 3. Tratamento de exceções (`ExceptionHandler`)

Concern incluído no controller base. Faz `rescue_from` na borda e renderiza tudo
no envelope de erro, mapeando cada exceção para `(message, error_code, status)`.

```ruby
# frozen_string_literal: true

module ExceptionHandler
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError do |e|
      Rails.logger.error(e)
      handle_exception(e, :internal_server_error, ErrorMapper.unknown_error)
    end

    rescue_from ActiveRecord::RecordNotFound do |e|
      message = ErrorMapper.record_not_found_message_for(e.model)
      Rails.logger.error(e)
      render json: ApiResponseSerializer.render(
        {},
        success: false,
        message: message,
        error_code: ErrorMapper.record_not_found.code
      ), status: :not_found
    end

    rescue_from ActiveRecord::RecordInvalid do |e|
      Rails.logger.error(e)
      render json: ApiResponseSerializer.render(
        {},
        success: false,
        message: e.record.errors.full_messages.join(", "),
        error_code: ErrorMapper.record_invalid.code
      ), status: :unprocessable_entity
    end

    rescue_from ArgumentError do |e|
      Rails.logger.error(e)
      render json: ApiResponseSerializer.render(
        {},
        success: false,
        message: e.message,
        error_code: ErrorMapper.record_invalid.code
      ), status: :unprocessable_entity
    end

    rescue_from ActiveRecord::RecordNotUnique do |e|
      Rails.logger.error(e)
      render json: ApiResponseSerializer.render(
        {},
        success: false,
        message: "Record already exists",
        error_code: ErrorMapper.record_invalid.code
      ), status: :conflict
    end

    rescue_from ActionController::ParameterMissing do |e|
      Rails.logger.error(e)
      render json: ApiResponseSerializer.render(
        {},
        success: false,
        message: e.message,
        error_code: ErrorMapper.missing_parameter.code
      ), status: :bad_request
    end
  end

  private

  def handle_exception(exception, status, error)
    Rails.logger.error(exception)
    render json: ApiResponseSerializer.render(
      {},
      success: false,
      message: error.message,
      error_code: error.code
    ), status: status
  end
end
```

> A ordem importa: `rescue_from StandardError` vem primeiro como fallback, mas o
> Rails avalia os handlers do **mais específico para o mais genérico**, então as
> exceções específicas (RecordNotFound, etc.) têm precedência.

### 4. Parâmetros de paginação (`PaginationParams`)

Concern que sanitiza `page`/`perPage` e monta o bloco `pagination` a partir de uma
relação Kaminari.

```ruby
# frozen_string_literal: true

module PaginationParams
  extend ActiveSupport::Concern

  def per_page_param(limit: 50, default: 10)
    per_page = params[:perPage]&.to_i || params[:per_page]&.to_i || default
    return default if per_page < 1
    return limit if per_page > limit
    per_page
  end

  def page_param
    page = params[:page]&.to_i || 1
    return 1 if page < 1
    page
  end

  def pagination_for(relation)
    {
      currentPage: relation.current_page,
      nextPage: relation.next_page,
      prevPage: relation.prev_page,
      totalPages: relation.total_pages,
      totalCount: relation.total_count
    }
  end
end
```

### 5. Controller base

Inclui os dois concerns e aplica auth. Todo controller de API herda daqui.

```ruby
# frozen_string_literal: true

module Api
  class BaseController < ActionController::API
    include ExceptionHandler
    include PaginationParams

    before_action :authenticate_user!
    before_action :set_user

    private

    def set_user
      @user = current_user
    end
  end
end
```

### 6. Serializers de domínio

Definem **só o conteúdo de `data`** (nunca o envelope). Usam o padrão Blueprinter de
`view :default` (listas, enxuto) e `view :extended` (detalhe, com timestamps e
campos derivados). O controller escolhe a view via `serializer_view:`.

```ruby
# app/serializers/v1/financial/transaction_serializer.rb
module V1
  module Financial
    class TransactionSerializer < Blueprinter::Base
      identifier :id

      view :default do
        fields :amount, :transaction_type, :description, :occurred_at, :category_id
      end

      view :extended do
        include_view :default
        fields :metadata, :artifact_id, :created_at, :updated_at, :budget_warnings

        association :category, blueprint: V1::Financial::CategorySerializer, view: :default
      end
    end
  end
end
```

```ruby
# app/serializers/v1/financial/category_serializer.rb
module V1
  module Financial
    class CategorySerializer < Blueprinter::Base
      identifier :id

      view :default do
        fields :name
      end

      view :extended do
        include_view :default
        fields :created_at, :updated_at
      end
    end
  end
end
```

```ruby
# app/serializers/v1/financial/budget_serializer.rb
module V1
  module Financial
    class BudgetSerializer < Blueprinter::Base
      identifier :id

      view :default do
        fields :period_type, :period_start, :period_end, :limit_amount
      end

      view :extended do
        include_view :default
        fields :spent_amount, :remaining, :usage_percent, :created_at, :updated_at
      end
    end
  end
end
```

```ruby
# app/serializers/v1/financial/summary_serializer.rb — serializer aninhado
module V1
  module Financial
    class SummarySerializer < Blueprinter::Base
      class CategoryBreakdownSerializer < Blueprinter::Base
        fields :category_id, :category_name, :amount
      end

      fields :total_amount, :transaction_count, :by_type

      association :by_category, blueprint: CategoryBreakdownSerializer
    end
  end
end
```

```ruby
# app/serializers/v1/artifact_serializer.rb — campo derivado (file_url) na view extended
module V1
  class ArtifactSerializer < Blueprinter::Base
    identifier :id

    view :default do
      fields :artifact_type, :status, :source, :occurred_at, :created_at, :updated_at
    end

    view :extended do
      include_view :default

      field :file_url do |artifact|
        next nil unless artifact.file.attached?

        Rails.application.routes.url_helpers.rails_blob_path(artifact.file, only_path: true)
      end

      field :processed_data
    end
  end
end
```

```ruby
# app/serializers/v1/user_serializer.rb — serializer simples (sem views)
module V1
  class UserSerializer < Blueprinter::Base
    identifier :id

    fields :name, :email, :phone, :created_at, :updated_at
  end
end
```

```ruby
# app/serializers/v1/chat/message_serializer.rb
module V1
  module Chat
    class MessageSerializer < Blueprinter::Base
      identifier :id

      view :default do
        fields :role, :kind, :body, :status, :intent, :conversation_id,
               :parent_message_id, :created_at, :updated_at
      end

      view :extended do
        include_view :default

        fields :payload, :error

        field :audio_url do |message|
          next nil unless message.audio.attached?

          Rails.application.routes.url_helpers.rails_blob_path(message.audio, only_path: true)
        end
      end
    end
  end
end
```

```ruby
# app/serializers/v1/chat/conversation_serializer.rb
module V1
  module Chat
    class ConversationSerializer < Blueprinter::Base
      identifier :id

      view :default do
        fields :title, :archived_at, :created_at, :updated_at
      end

      view :extended do
        include_view :default

        field :messages_count do |conversation|
          conversation.messages.count
        end
      end
    end
  end
end
```

---

## Uso real nos controllers

As 6 formas do envelope, extraídas dos controllers do projeto.

**Coleção paginada** (`render_data_array` + `pagination_for`):

```ruby
# transactions_controller.rb#index
def index
  transactions = @user.transactions
                      .by_type(params[:transaction_type])
                      .by_category(params[:category_id])
                      .occurred_from(params[:from])
                      .occurred_until(params[:to])
                      .order(occurred_at: :desc, created_at: :desc)
                      .page(page_param)
                      .per(per_page_param)

  render json: ApiResponseSerializer.render_data_array(
    transactions,
    serializer: ::V1::Financial::TransactionSerializer,
    serializer_view: :default,
    pagination: pagination_for(transactions)
  ), status: :ok
end
```

**Recurso único** (view `:extended`):

```ruby
# transactions_controller.rb#show
def show
  transaction = @user.transactions.find(params[:id])

  render json: ApiResponseSerializer.render(
    transaction,
    serializer: ::V1::Financial::TransactionSerializer,
    serializer_view: :extended
  ), status: :ok
end
```

**Criação** (recurso + `message`, status `:created`):

```ruby
# transactions_controller.rb#create
def create
  transaction = UseCase::Financial::Transaction::CreateTransactionUseCase.new.call(
    user: @user,
    **transaction_params.to_h.symbolize_keys
  )

  render json: ApiResponseSerializer.render(
    transaction,
    serializer: ::V1::Financial::TransactionSerializer,
    serializer_view: :extended,
    message: "Transaction created successfully."
  ), status: :created
end
```

**Confirmação sem corpo** (`{}` + só `message`):

```ruby
# transactions_controller.rb#destroy
def destroy
  @user.transactions.find(params[:id]).destroy!

  render json: ApiResponseSerializer.render(
    {},
    message: "Transaction deleted successfully."
  ), status: :ok
end
```

**Coleção com metadata** (`render_data_array` + `metadata`):

```ruby
# budgets_controller.rb#current
def current
  result = UseCase::Financial::Budget::ListCurrentBudgetsUseCase.new.call(
    user: @user,
    date: params[:date]
  )

  render json: ApiResponseSerializer.render_data_array(
    result.budgets,
    serializer: ::V1::Financial::BudgetSerializer,
    serializer_view: :extended,
    metadata: { reference_date: result.reference_date }
  ), status: :ok
end
```

**Payload montado à mão** (sem `serializer:`, `data` recebe o hash cru):

```ruby
# user_controller.rb#show
def show
  render json: ApiResponseSerializer.render(
    { user: ::V1::UserSerializer.render_as_hash(@user) }
  ), status: :ok
end
```

**Erro detalhado** (forma com objeto `error`, no webhook inbound):

```ruby
# inbound/messages_controller.rb#validate_signature
def validate_signature
  return if messaging_provider.valid_signature?(request, request.request_parameters)

  render json: ApiResponseSerializer.error(
    ErrorMapper::ERRORS[:unauthorized]
  ), status: :unauthorized
end
```

---

## Schema (TypeScript)

```ts
// Envelope genérico
interface ApiResponse<T> {
  success: boolean;
  data?: T;
  message?: string;
  errorCode?: number;
  pagination?: Pagination;
  metadata?: Record<string, unknown>;
  filterOptions?: Record<string, unknown>;
  error?: ApiError;
}

interface Pagination {
  currentPage: number;
  nextPage: number | null;
  prevPage: number | null;
  totalPages: number;
  totalCount: number;
}

interface ApiError {
  code: number;
  title: string;
  description?: string | null;
}

// Atalhos por shape
type ApiSuccess<T> = ApiResponse<T> & { success: true; data: T };
type ApiList<T>    = ApiResponse<T[]> & { success: true; data: T[]; pagination: Pagination };
type ApiFailure    = ApiResponse<never> & { success: false; errorCode: number };
```

---

## Cliente HTTP de referência

O cliente decide o fluxo por `success`, não pelo status HTTP:

```ts
const BASE_URL = "http://localhost:3000";

async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
  const token = localStorage.getItem("");

  const res = await fetch(`${BASE_URL}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(init.headers ?? {}),
    },
  });

  const json = (await res.json()) as ApiResponse<T>;
  if (!json.success) {
    throw new ApiError(json.message ?? "Unknown error", json.errorCode ?? res.status, res.status);
  }
  return json.data as T;
}

class ApiError extends Error {
  constructor(message: string, public code: number, public status: number) {
    super(message);
  }
}
```

---

## Checklist de portabilidade

Ao levar o padrão para outro projeto:

- [ ] Copiar/adaptar `ApiResponseSerializer` (depende de **Blueprinter**).
- [ ] Copiar `ErrorMapper` e ajustar os códigos ao novo domínio.
- [ ] Incluir `ExceptionHandler` no controller base e mapear as exceções do novo stack.
- [ ] Incluir `PaginationParams` (depende de **Kaminari**: `.page`/`.per`,
      `current_page`/`next_page`/`prev_page`/`total_pages`/`total_count`).
- [ ] Criar serializers de domínio com `view :default` / `view :extended`.
- [ ] Manter a separação de casing: **snake_case** no domínio, **camelCase** no envelope.
- [ ] Garantir que campos opcionais sejam **omitidos** (não `null`).

> **Sem Blueprinter/Kaminari:** o padrão é só um shape de JSON. Basta reproduzir o
> envelope (mesmas chaves e regras de omissão) e o bloco de paginação; a tecnologia
> de serialização/paginação é detalhe de implementação.
