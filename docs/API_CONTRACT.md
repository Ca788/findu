# FindU — Contrato da API

Documento gerado a partir do código (`config/routes.rb`, `app/controllers/api/v1/**`, `app/serializers/**`, `app/models/**`).

Versão: **v1**
Formato de payload: **JSON** (`Content-Type: application/json`), exceto upload de arquivo (`multipart/form-data`).
Charset: **UTF-8**.

---

## 1. Visão geral

A API segue convenções REST, é versionada por path (`/api/v1`) e organizada em **6 módulos**:

| Módulo | Prefixo | Escopo |
|---|---|---|
| Auth (Sessions / Passwords) | `/api/v1` | Login/logout, reset de senha |
| User | `/api/v1/user` | Cadastro e perfil do usuário |
| Artifacts | `/api/v1/artifacts` | Upload e leitura de comprovantes (OCR assíncrono) |
| Financial | `/api/v1/financial` | Categorias, transações, orçamentos e sumário |
| Chat | `/api/v1/chat` | Conversas e mensagens com o assistente |
| Inbound | `/api/v1/inbound` | Webhooks de provedores de mensageria |

Cada recurso é **escopado pelo usuário autenticado** (`current_user`). Não há cross-tenant: o `BaseController` chama `authenticate_user!` e injeta `@user = current_user`, e todas as queries em listas/show partem de `@user.<association>` ou `find` por `@user.<association>`.

---

## 2. Autenticação

A API usa **Devise + Devise-JWT (JTIMatcher)**.

- **Login** (`POST /api/v1/login`) retorna o token JWT no header de resposta `Authorization: Bearer <token>`.
- **Cadastro** (`POST /api/v1/user`) também retorna o token no header `Authorization`.
- **Logout** (`DELETE /api/v1/logout`) revoga o token atual (atualiza `jti` do usuário).
- Expiração padrão: **24 horas**.
- Em todas as rotas protegidas, envie:

```http
Authorization: Bearer <jwt>
```

Endpoints **públicos** (sem autenticação):

- `POST /api/v1/login`
- `POST /api/v1/user` (cadastro)
- `POST /api/v1/password` (esqueci minha senha)
- `PATCH /api/v1/password` (redefinir senha por token)
- `POST /api/v1/inbound/messages` (validado por assinatura do provedor)
- `GET /health`

---

## 3. Envelope de resposta (padrão)

Toda resposta JSON da API usa o **envelope `ApiResponseSerializer`**:

### 3.1 Sucesso com objeto

```json
{
  "success": true,
  "message": "string (opcional)",
  "metadata": { "...": "..." },
  "data": { "...": "objeto serializado" }
}
```

### 3.2 Sucesso com lista paginada

```json
{
  "success": true,
  "pagination": {
    "currentPage": 1,
    "nextPage": 2,
    "prevPage": null,
    "totalPages": 7,
    "totalCount": 63
  },
  "metadata": { "...": "..." },
  "data": [ { "..." }, { "..." } ]
}
```

### 3.3 Erro

```json
{
  "success": false,
  "message": "Descrição amigável",
  "errorCode": 1003,
  "error": {
    "code": 1003,
    "title": "Validation failed"
  }
}
```

Campos presentes só quando aplicáveis: `message`, `metadata`, `pagination`, `errorCode`, `error`, `filterOptions`.

---

## 4. Paginação e filtros

Listas usam **Kaminari** via concern `PaginationParams`:

| Query param | Tipo | Default | Limite | Descrição |
|---|---|---|---|---|
| `page` | int | `1` | — | Página (1-based). Valores `< 1` são tratados como `1`. |
| `perPage` *(ou `per_page`)* | int | `10` | `50` | Itens por página. Acima do limite é truncado para `50`. |

Resposta inclui o objeto `pagination` mostrado em 3.2.

---

## 5. Convenções

- **IDs:** UUID v4 (`string`).
- **Datas/horas:** `created_at`, `updated_at`, `occurred_at`, `archived_at`, `deleted_at` em **ISO-8601** (`2026-06-06T15:42:00Z`).
- **Períodos de orçamento:** `period_start`, `period_end` em **`YYYY-MM-DD`** (date).
- **Valores monetários:** `decimal(10,2)`, sempre positivos (o tipo income/expense é separado por `transaction_type`).
- **Soft-delete / arquivamento:** chats usam `archived_at`; mensagens usam `deleted_at`; orçamentos têm `deleted_at` no schema mas o controller faz `destroy!`.
- **Upload de arquivo:** ActiveStorage — `file_url` é retornado como **path relativo** (`/rails/active_storage/blobs/...`).
- **JSONB:** `metadata`, `payload`, `processed_data`, `raw_data`, `error`, `settings` são objetos arbitrários (ver módulo específico).

---

## 6. Erros padronizados

Mapeados em `app/controllers/error_mapper.rb` e `ExceptionHandler`:

| Exceção interna | HTTP | `errorCode` | `message` típica |
|---|---|---|---|
| `StandardError` (fallback) | `500` | `500` | "Unknown Error" |
| `ActiveRecord::RecordNotFound` | `404` | `404` | `"<Model> not found"` (ex.: `"Transaction not found"`) |
| `ActiveRecord::RecordInvalid` | `422` | `1003` | mensagens de validação concatenadas |
| `ArgumentError` | `422` | `1003` | mensagem da exceção |
| `ActiveRecord::RecordNotUnique` | `409` | `1003` | `"Record already exists"` |
| `ActionController::ParameterMissing` | `400` | `1002` | mensagem da exceção |
| Credenciais inválidas (login/inbound) | `401` | `1001` | `"Invalid credentials"` |

---

## 7. Módulos e endpoints

> **Legenda:** **Auth** = requer JWT. **Público** = não requer.
> **View default vs extended:** definida no Blueprinter; `index` usa `default`, `show`/`create`/`update` geralmente usam `extended`.

### 7.1 Auth — Sessions

Controller: `Api::V1::SessionsController` (herda de `Devise::SessionsController`).

#### `POST /api/v1/login` — Público

Autentica usuário por e-mail e senha. Retorna o token JWT no header `Authorization`.

**Body**

```json
{
  "user": {
    "email": "fulano@exemplo.com",
    "password": "senha123"
  }
}
```

**Response `200 OK`** (header `Authorization: Bearer <jwt>`)

```json
{
  "success": true,
  "message": "Logged in successfully.",
  "data": {
    "user": {
      "id": "uuid",
      "name": "Fulano",
      "email": "fulano@exemplo.com",
      "phone": "+5511999999999",
      "created_at": "...",
      "updated_at": "..."
    }
  }
}
```

**Erros:** `401` credenciais inválidas.

---

#### `DELETE /api/v1/logout` — Auth

Revoga o JWT atual (atualiza `jti`).

**Response `200 OK`**

```json
{ "success": true, "message": "Logged out successfully.", "data": {} }
```

---

### 7.2 Auth — Passwords

Controller: `Api::V1::PasswordsController`.

#### `POST /api/v1/password` — Público

Envia e-mail com instruções de redefinição (resposta é sempre genérica para evitar enumeration).

**Body**

```json
{ "user": { "email": "fulano@exemplo.com" } }
```

**Response `200 OK`**

```json
{
  "success": true,
  "message": "If the email exists, password reset instructions were sent.",
  "data": {}
}
```

---

#### `PATCH /api/v1/password` — Público

Redefine a senha usando o `reset_password_token` recebido por e-mail.

**Body**

```json
{
  "user": {
    "reset_password_token": "abc123",
    "password": "novaSenha",
    "password_confirmation": "novaSenha"
  }
}
```

**Response `200 OK`**

```json
{ "success": true, "message": "Password reset successfully.", "data": {} }
```

**Erros:** `422` token inválido/expirado, senhas divergentes.

> O `GET /users/password/edit` existe apenas para satisfazer o template do Devise mailer e redireciona o frontend a chamar este `PATCH`.

---

### 7.3 User

Controller: `Api::V1::UserController`.

#### `POST /api/v1/user` — Público

Cria um novo usuário. Retorna token JWT no header `Authorization`.

**Body**

```json
{
  "user": {
    "name": "Fulano",
    "email": "fulano@exemplo.com",
    "phone": "+5511999999999",
    "password": "senha123",
    "password_confirmation": "senha123"
  }
}
```

**Response `201 Created`** (header `Authorization: Bearer <jwt>`)

```json
{
  "success": true,
  "message": "User created successfully.",
  "data": {
    "user": { "id": "uuid", "name": "...", "email": "...", "phone": "...", "created_at": "...", "updated_at": "..." }
  }
}
```

**Erros:** `422` validação (e-mail já existe, formato inválido, senha curta etc.).

---

#### `GET /api/v1/user` — Auth

Retorna o perfil do usuário autenticado.

**Response `200 OK`**

```json
{
  "success": true,
  "data": {
    "user": { "id": "uuid", "name": "...", "email": "...", "phone": "...", "created_at": "...", "updated_at": "..." }
  }
}
```

---

### 7.4 Artifacts

Controller: `Api::V1::ArtifactsController`.
Recurso: comprovantes/notas fiscais enviados pelo usuário; processamento OCR é assíncrono (`Artifacts::ProcessOcrJob`).

**Schema (view extended)**

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `artifact_type` | string | Ex.: `receipt`, `invoice` (livre, validado apenas como `presence`) |
| `status` | enum | `pending` \| `processed` \| `failed` \| `needs_review` |
| `source` | string \| null | Origem (ex.: `whatsapp`, `upload`) |
| `occurred_at` | datetime \| null | Data extraída pelo OCR |
| `file_url` | string \| null | Path do ActiveStorage (somente view `extended`) |
| `processed_data` | object \| null | JSONB com dados extraídos pelo OCR (somente `extended`) |
| `created_at`, `updated_at` | datetime | |

#### `GET /api/v1/artifacts` — Auth

Lista comprovantes do usuário, ordenados por `created_at desc`. Paginação padrão.

**Query params:** `page`, `perPage`.
**Response `200 OK`** — envelope paginado com `data: [Artifact(view: default)]`.

#### `GET /api/v1/artifacts/:id` — Auth

Detalhe (view `extended`).
**Response `200 OK`** — `data: Artifact(view: extended)`.
**Erros:** `404` se não pertencer ao usuário.

#### `POST /api/v1/artifacts` — Auth — `multipart/form-data`

Envia arquivo para processamento OCR.

**Form-data**

| Campo | Tipo | Obrigatório | Notas |
|---|---|---|---|
| `file` | file | sim | Imagem/PDF do comprovante |
| `artifact_type` | string | sim | Tipo de comprovante |
| `source` | string | não | Origem do upload |

**Response `202 Accepted`**

```json
{
  "success": true,
  "message": "Artifact uploaded; OCR processing queued.",
  "data": { "id": "uuid", "artifact_type": "receipt", "status": "pending", "file_url": "...", "processed_data": null, "..." }
}
```

**Erros:** `422` se `file` ausente (`ArgumentError`) ou validação.

---

### 7.5 Financial — Categories

Controller: `Api::V1::Financial::CategoriesController`.

**Schema**

| Campo | Tipo | View |
|---|---|---|
| `id` | UUID | default |
| `name` | string | default |
| `created_at`, `updated_at` | datetime | extended |

#### `GET /api/v1/financial/categories` — Auth

Lista categorias do usuário, ordenadas por `name asc`. Paginação padrão.
**Query params:** `page`, `perPage`.

#### `GET /api/v1/financial/categories/:id` — Auth

#### `POST /api/v1/financial/categories` — Auth

**Body**

```json
{ "category": { "name": "Alimentação" } }
```

**Response `201 Created`** — `message: "Category created successfully."`

#### `PATCH /api/v1/financial/categories/:id` — Auth

**Body**

```json
{ "category": { "name": "Mercado" } }
```

**Response `200 OK`** — `message: "Category updated successfully."`

#### `DELETE /api/v1/financial/categories/:id` — Auth

**Response `200 OK`** — `message: "Category deleted successfully."`, `data: {}`.

---

### 7.6 Financial — Transactions

Controller: `Api::V1::Financial::TransactionsController`.

**Schema (view extended)**

| Campo | Tipo | View | Notas |
|---|---|---|---|
| `id` | UUID | default | |
| `amount` | decimal(10,2) | default | sempre `> 0` |
| `transaction_type` | enum | default | `expense` \| `income` |
| `description` | string \| null | default | |
| `occurred_at` | datetime \| null | default | |
| `category_id` | UUID \| null | default | |
| `metadata` | object | extended | JSONB livre |
| `artifact_id` | UUID \| null | extended | Quando originada de um comprovante |
| `budget_warnings` | array | extended | Avisos do consumo de orçamento (ex.: estouro) |
| `category` | object \| null | extended | Categoria embutida (view default) |
| `created_at`, `updated_at` | datetime | extended | |

#### `GET /api/v1/financial/transactions` — Auth

Lista transações ordenadas por `occurred_at desc, created_at desc`. Paginação padrão.

**Query params**

| Param | Tipo | Notas |
|---|---|---|
| `page`, `perPage` | int | Paginação |
| `transaction_type` | string | `expense` ou `income` |
| `category_id` | UUID | Filtra por categoria |
| `from` | datetime/date | `occurred_at >= from` |
| `to` | datetime/date | `occurred_at <= to` |

#### `GET /api/v1/financial/transactions/:id` — Auth

Retorna a transação (view `extended`).

#### `POST /api/v1/financial/transactions` — Auth

**Body** (campos permitidos = `PERMITTED_ATTRIBUTES`)

```json
{
  "transaction": {
    "amount": "129.90",
    "transaction_type": "expense",
    "description": "Mercado",
    "occurred_at": "2026-06-05T12:00:00Z",
    "category_id": "uuid",
    "metadata": { "channel": "manual" }
  }
}
```

**Response `201 Created`** — `message: "Transaction created successfully."`

#### `PATCH /api/v1/financial/transactions/:id` — Auth

Mesmo body do `POST` (todos os campos são opcionais na atualização).
**Response `200 OK`** — `message: "Transaction updated successfully."`

#### `DELETE /api/v1/financial/transactions/:id` — Auth

**Response `200 OK`** — `message: "Transaction deleted successfully."`, `data: {}`.

---

### 7.7 Financial — Budgets

Controller: `Api::V1::Financial::BudgetsController`.

**Schema (view extended)**

| Campo | Tipo | View | Notas |
|---|---|---|---|
| `id` | UUID | default | |
| `period_type` | enum | default | `weekly` \| `monthly` \| `yearly` \| `custom` |
| `period_start` | date | default | |
| `period_end` | date | default | `> period_start` |
| `limit_amount` | decimal(10,2) | default | `> 0` |
| `spent_amount` | decimal | extended | Computado: soma de `expense` no período |
| `remaining` | decimal | extended | `limit_amount - spent_amount` |
| `usage_percent` | float | extended | 0–100+ (pode passar de 100 se estourou) |
| `created_at`, `updated_at` | datetime | extended | |

#### `GET /api/v1/financial/budgets` — Auth

Lista orçamentos ordenados por `period_start desc`.

**Query params:** `page`, `perPage`, `period_type` (`weekly|monthly|yearly|custom`).

#### `GET /api/v1/financial/budgets/current` — Auth

Retorna os orçamentos vigentes na data informada (ou hoje, se omitida).

**Query params**

| Param | Tipo | Default | Notas |
|---|---|---|---|
| `date` | date (`YYYY-MM-DD`) | hoje | Data de referência |

**Response `200 OK`**

```json
{
  "success": true,
  "metadata": { "reference_date": "2026-06-06" },
  "data": [ { "id": "...", "period_type": "monthly", "period_start": "2026-06-01", "period_end": "2026-06-30", "limit_amount": "2000.00", "spent_amount": "850.40", "remaining": "1149.60", "usage_percent": 42.52, "..." } ]
}
```

#### `GET /api/v1/financial/budgets/:id` — Auth

#### `POST /api/v1/financial/budgets` — Auth

**Body** (campos permitidos = `PERMITTED_ATTRIBUTES`)

```json
{
  "budget": {
    "period_type": "monthly",
    "period_start": "2026-06-01",
    "period_end": "2026-06-30",
    "limit_amount": "2000.00"
  }
}
```

**Response `201 Created`** — `message: "Budget created successfully."`

#### `PATCH /api/v1/financial/budgets/:id` — Auth

**Response `200 OK`** — `message: "Budget updated successfully."`

#### `DELETE /api/v1/financial/budgets/:id` — Auth

**Response `200 OK`** — `message: "Budget deleted successfully."`, `data: {}`.

**Erros específicos:** `422` `period_end` ≤ `period_start`; `422` se `(period_start, period_end)` já existirem para o usuário (unicidade).

---

### 7.8 Financial — Summary

Controller: `Api::V1::Financial::SummaryController`.

#### `GET /api/v1/financial/summary` — Auth

Resumo agregado de transações por período/tipo/categoria.

**Query params**

| Param | Tipo | Notas |
|---|---|---|
| `from` | date/datetime | Início do período |
| `to` | date/datetime | Fim do período |
| `transaction_type` | string | `expense` ou `income` (opcional) |
| `category_id` | UUID | Filtra por categoria (opcional) |

**Response `200 OK`**

```json
{
  "success": true,
  "metadata": { "from": "2026-06-01", "to": "2026-06-30" },
  "data": {
    "total_amount": "1530.80",
    "transaction_count": 23,
    "by_type": { "expense": "1230.80", "income": "300.00" },
    "by_category": [
      { "category_id": "uuid", "category_name": "Alimentação", "amount": "450.20" },
      { "category_id": "uuid", "category_name": "Transporte", "amount": "180.00" }
    ]
  }
}
```

---

### 7.9 Chat — Conversations

Controller: `Api::V1::Chat::ConversationsController`.

**Schema (view extended)**

| Campo | Tipo | View | Notas |
|---|---|---|---|
| `id` | UUID | default | |
| `title` | string \| null | default | |
| `archived_at` | datetime \| null | default | |
| `created_at`, `updated_at` | datetime | default | |
| `messages_count` | int | extended | Total de mensagens da conversa |

#### `GET /api/v1/chat/conversations` — Auth

Lista conversas **ativas** (não arquivadas), ordenadas por `updated_at desc`.
**Query params:** `page`, `perPage`.

#### `GET /api/v1/chat/conversations/:id` — Auth

Retorna conversa (view `extended`).

#### `POST /api/v1/chat/conversations` — Auth

**Body**

```json
{ "title": "Compras de junho" }
```

**Response `201 Created`** — `message: "Conversation created."`

#### `DELETE /api/v1/chat/conversations/:id` — Auth

Faz **soft-archive** (`archived_at = now`). Idempotente — se já arquivada, retorna sucesso.

**Response `200 OK`** — `message: "Conversation archived."`, `data: {}`.

---

### 7.10 Chat — Messages

Controller: `Api::V1::Chat::MessagesController`.
Escopadas pela conversa (`conversation_id` no path) **e pelo usuário** (`@user.chat_conversations.find(...)`).

**Schema (view extended)**

| Campo | Tipo | View | Notas |
|---|---|---|---|
| `id` | UUID | default | |
| `conversation_id` | UUID | default | |
| `parent_message_id` | UUID \| null | default | Resposta a outra mensagem |
| `role` | enum | default | `user` \| `assistant` \| `system` |
| `kind` | enum | default | `text` \| `audio` |
| `body` | string \| null | default | Conteúdo textual (transcrição quando `kind=audio`) |
| `status` | enum | default | `pending` \| `processing` \| `completed` \| `failed` |
| `intent` | string \| null | default | Intenção detectada pelo classificador |
| `created_at`, `updated_at` | datetime | default | |
| `payload` | object \| null | extended | JSONB com saída estruturada do LLM |
| `error` | object \| null | extended | JSONB com detalhes de erro do processamento |
| `audio_url` | string \| null | extended | Path do áudio em ActiveStorage |

#### `GET /api/v1/chat/conversations/:conversation_id/messages` — Auth

Lista mensagens não-deletadas da conversa, ordenadas por `created_at asc`.
**Query params:** `page`, `perPage`.

#### `GET /api/v1/chat/conversations/:conversation_id/messages/:id` — Auth

Retorna mensagem (view `extended`). Mensagens deletadas retornam `404`.

#### `POST /api/v1/chat/conversations/:conversation_id/messages` — Auth — `multipart/form-data` (se enviar áudio) ou `application/json`

Cria uma nova mensagem do usuário e enfileira processamento assíncrono pelo assistente.

**Form-data / Body**

| Campo | Tipo | Obrigatório | Notas |
|---|---|---|---|
| `body` | string | parcial | Obrigatório se não enviar `audio` |
| `audio` | file | parcial | Obrigatório se não enviar `body` |
| `client_message_id` | UUID | não | Idempotência por usuário (índice único `(user_id, client_message_id)`) |

**Response `202 Accepted`**

```json
{
  "success": true,
  "message": "Message queued for processing.",
  "data": {
    "id": "uuid",
    "conversation_id": "uuid",
    "parent_message_id": null,
    "role": "user",
    "kind": "text",
    "body": "Quanto gastei em junho?",
    "status": "pending",
    "intent": null,
    "payload": null,
    "error": null,
    "audio_url": null,
    "created_at": "...",
    "updated_at": "..."
  }
}
```

**Erros:** `404` se a conversa não pertencer ao usuário; `422` se `body` e `audio` ausentes; `409` se `client_message_id` repetido para o mesmo usuário.

---

### 7.11 Inbound — Webhook de mensageria

Controller: `Api::V1::Inbound::MessagesController` (não herda de `BaseController`; **não usa JWT**, valida assinatura HMAC do provedor).

#### `POST /api/v1/inbound/messages` — Público (assinado)

Recebe mensagens de um provedor (ex.: WhatsApp). Payload e validação dependem de `Messaging::ProviderFactory.build`.

- Se a assinatura for inválida: `401 Unauthorized` com envelope de erro padrão.
- Se válida: enfileira `UseCase::Messaging::ProcessInboundMessageUseCase` e responde **`200 OK` com body vazio**.

---

## 8. Schemas — resumo

Tabelas reais (`schema.rb`-equivalente) com tipos:

### User (`users`)

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | PK |
| `name` | string | obrigatório |
| `email` | string | único |
| `phone` | string | opcional |
| `encrypted_password` | string | interno (Devise) |
| `jti` | string | rotacionado a cada logout |
| `reset_password_token` | string | único, opcional |
| `reset_password_sent_at` | datetime | |
| `settings` | jsonb | livre |
| `deleted_at` | datetime | reservado para soft-delete |
| `created_at`, `updated_at` | datetime | |

### Artifact (`artifacts`)

`id`, `user_id`, `artifact_type`, `status` (enum), `source`, `occurred_at`, `raw_data` (jsonb), `processed_data` (jsonb), `deleted_at`, `created_at`, `updated_at`, `file` (ActiveStorage).

### Financial::Category (`categories`)

`id`, `user_id`, `name`, `created_at`, `updated_at`.

### Financial::Transaction (`transactions`)

`id`, `user_id`, `category_id` (FK opcional), `artifact_id` (FK opcional), `amount` (decimal 10,2 > 0), `transaction_type` (`expense|income`), `description`, `occurred_at`, `metadata` (jsonb), `created_at`, `updated_at`.

### Financial::Budget (`budgets`)

`id`, `user_id`, `period_type` (enum), `period_start`, `period_end`, `limit_amount` (decimal 10,2 > 0), `deleted_at`, `created_at`, `updated_at`. **Unique** `(user_id, period_start, period_end)`.

### Chat::Conversation (`chat_conversations`)

`id`, `user_id`, `title`, `archived_at`, `created_at`, `updated_at`.

### Chat::Message (`chat_messages`)

`id`, `user_id`, `conversation_id`, `parent_message_id` (opcional), `client_message_id` (UUID, único por user quando presente), `role`, `kind`, `body`, `status`, `intent`, `payload` (jsonb), `error` (jsonb), `deleted_at`, `created_at`, `updated_at`, `audio` (ActiveStorage).

---

## 9. Tabela rápida de endpoints

| Método | Path | Auth | Controller |
|---|---|---|---|
| `GET`    | `/health` | Público | `HealthController#show` |
| `POST`   | `/api/v1/login` | Público | `Sessions#create` |
| `DELETE` | `/api/v1/logout` | Auth | `Sessions#destroy` |
| `POST`   | `/api/v1/user` | Público | `User#create` |
| `GET`    | `/api/v1/user` | Auth | `User#show` |
| `POST`   | `/api/v1/password` | Público | `Passwords#create` |
| `PATCH`  | `/api/v1/password` | Público | `Passwords#update` |
| `GET`    | `/api/v1/artifacts` | Auth | `Artifacts#index` |
| `GET`    | `/api/v1/artifacts/:id` | Auth | `Artifacts#show` |
| `POST`   | `/api/v1/artifacts` | Auth | `Artifacts#create` |
| `GET`    | `/api/v1/financial/categories` | Auth | `Financial::Categories#index` |
| `GET`    | `/api/v1/financial/categories/:id` | Auth | `Financial::Categories#show` |
| `POST`   | `/api/v1/financial/categories` | Auth | `Financial::Categories#create` |
| `PATCH`  | `/api/v1/financial/categories/:id` | Auth | `Financial::Categories#update` |
| `DELETE` | `/api/v1/financial/categories/:id` | Auth | `Financial::Categories#destroy` |
| `GET`    | `/api/v1/financial/transactions` | Auth | `Financial::Transactions#index` |
| `GET`    | `/api/v1/financial/transactions/:id` | Auth | `Financial::Transactions#show` |
| `POST`   | `/api/v1/financial/transactions` | Auth | `Financial::Transactions#create` |
| `PATCH`  | `/api/v1/financial/transactions/:id` | Auth | `Financial::Transactions#update` |
| `DELETE` | `/api/v1/financial/transactions/:id` | Auth | `Financial::Transactions#destroy` |
| `GET`    | `/api/v1/financial/budgets` | Auth | `Financial::Budgets#index` |
| `GET`    | `/api/v1/financial/budgets/current` | Auth | `Financial::Budgets#current` |
| `GET`    | `/api/v1/financial/budgets/:id` | Auth | `Financial::Budgets#show` |
| `POST`   | `/api/v1/financial/budgets` | Auth | `Financial::Budgets#create` |
| `PATCH`  | `/api/v1/financial/budgets/:id` | Auth | `Financial::Budgets#update` |
| `DELETE` | `/api/v1/financial/budgets/:id` | Auth | `Financial::Budgets#destroy` |
| `GET`    | `/api/v1/financial/summary` | Auth | `Financial::Summary#show` |
| `GET`    | `/api/v1/chat/conversations` | Auth | `Chat::Conversations#index` |
| `GET`    | `/api/v1/chat/conversations/:id` | Auth | `Chat::Conversations#show` |
| `POST`   | `/api/v1/chat/conversations` | Auth | `Chat::Conversations#create` |
| `DELETE` | `/api/v1/chat/conversations/:id` | Auth | `Chat::Conversations#destroy` |
| `GET`    | `/api/v1/chat/conversations/:conversation_id/messages` | Auth | `Chat::Messages#index` |
| `GET`    | `/api/v1/chat/conversations/:conversation_id/messages/:id` | Auth | `Chat::Messages#show` |
| `POST`   | `/api/v1/chat/conversations/:conversation_id/messages` | Auth | `Chat::Messages#create` |
| `POST`   | `/api/v1/inbound/messages` | Assinatura | `Inbound::Messages#create` |

---

## 10. Exemplos `curl`

```bash
# Login
curl -X POST "$API/api/v1/login" \
  -H 'Content-Type: application/json' \
  -d '{"user":{"email":"fulano@exemplo.com","password":"senha123"}}' \
  -i

# Listar transações de junho/2026, paginadas
curl "$API/api/v1/financial/transactions?from=2026-06-01&to=2026-06-30&perPage=20&page=1" \
  -H "Authorization: Bearer $JWT"

# Criar uma transação
curl -X POST "$API/api/v1/financial/transactions" \
  -H "Authorization: Bearer $JWT" \
  -H 'Content-Type: application/json' \
  -d '{"transaction":{"amount":"129.90","transaction_type":"expense","description":"Mercado","occurred_at":"2026-06-05T12:00:00Z","category_id":"<uuid>"}}'

# Upload de comprovante
curl -X POST "$API/api/v1/artifacts" \
  -H "Authorization: Bearer $JWT" \
  -F 'file=@./nota.pdf' \
  -F 'artifact_type=receipt' \
  -F 'source=upload'

# Enviar mensagem ao chat
curl -X POST "$API/api/v1/chat/conversations/<conv-uuid>/messages" \
  -H "Authorization: Bearer $JWT" \
  -H 'Content-Type: application/json' \
  -d '{"body":"Quanto gastei em junho?","client_message_id":"<uuid>"}'
```
