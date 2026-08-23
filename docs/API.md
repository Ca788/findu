# Findu API — Reference para Front-end

Documentação completa da API REST do Findu.
Base URL local: `http://localhost:3000`

---

## Sumário

- [Convenções gerais](#convenções-gerais)
- [Formato de resposta](#formato-de-resposta)
- [Erros](#erros)
- [Paginação](#paginação)
- [Autenticação](#autenticação)
- [Endpoints](#endpoints)
  - [Auth & Sessão](#auth--sessão)
  - [Usuário](#usuário)
  - [Senha](#senha)
  - [Categorias](#categorias)
  - [Transações](#transações)
  - [Orçamentos](#orçamentos)
  - [Resumo financeiro](#resumo-financeiro)
  - [Artefatos (recibos)](#artefatos-recibos)
  - [Chat — Conversas](#chat--conversas)
  - [Chat — Mensagens](#chat--mensagens)
  - [Inbound (webhook)](#inbound-webhook)
  - [Healthcheck](#healthcheck)
- [Tipos e enums](#tipos-e-enums)

---

## Convenções gerais

- **Versionamento**: tudo sob `/api/v1/...`.
- **Content-Type**: `application/json`, exceto upload de arquivos (`multipart/form-data`).
- **IDs**: UUID v4 (string).
- **Datas**: ISO-8601 em UTC. Filtros aceitam `YYYY-MM-DD` ou ISO-8601 completo.
- **Valores monetários**: `decimal(10,2)` serializado como string ou number JSON. Sempre positivo; o tipo (`expense`/`income`) define a natureza.
- **camelCase vs snake_case**: o backend retorna **snake_case** nos campos de domínio (`transaction_type`, `occurred_at`, `created_at`) e **camelCase** apenas no envelope de paginação (`currentPage`, `totalCount`, `totalPages`).

## Formato de resposta

Todas as respostas seguem o envelope abaixo (gerado por `ApiResponseSerializer`).

### Sucesso — recurso único

```json
{
  "success": true,
  "message": "Transaction created successfully.",
  "data": {
    "id": "1f2a...",
    "amount": "50.00",
    "transaction_type": "expense",
    "description": "mercado",
    "occurred_at": "2026-05-24T18:00:00Z",
    "category_id": "ac3...",
    "metadata": {},
    "artifact_id": null,
    "created_at": "2026-05-24T18:00:01Z",
    "updated_at": "2026-05-24T18:00:01Z",
    "budget_warnings": [],
    "category": { "id": "ac3...", "name": "mercado" }
  }
}
```

### Sucesso — lista paginada

```json
{
  "success": true,
  "data": [ { "...": "..." } ],
  "pagination": {
    "currentPage": 1,
    "nextPage": 2,
    "prevPage": null,
    "totalPages": 5,
    "totalCount": 47
  }
}
```

### Sucesso — lista com metadata extra

Ex.: `GET /api/v1/financial/budgets/current` retorna a `reference_date`.

```json
{
  "success": true,
  "data": [ { "...": "..." } ],
  "metadata": { "reference_date": "2026-05-24" }
}
```

### Erro

```json
{
  "success": false,
  "message": "Validation failed",
  "errorCode": 1003
}
```

## Erros

Mapa central (`ErrorMapper`):

| `errorCode` | HTTP | Origem | Mensagem padrão |
|---|---|---|---|
| `500` | `500 Internal Server Error` | Qualquer `StandardError` não tratado | `Unknown Error` |
| `404` | `404 Not Found` | `ActiveRecord::RecordNotFound` | `<Modelo> not found` (ex.: `Transaction not found`) |
| `1001` | `401 Unauthorized` | Falha de auth (Devise, assinatura inválida no webhook) | `Invalid credentials` |
| `1002` | `400 Bad Request` | `ActionController::ParameterMissing` | `Missing parameter: <param>` |
| `1003` | `422 Unprocessable Entity` | `ActiveRecord::RecordInvalid`, `ArgumentError` | mensagem do erro de validação |
| `1003` | `409 Conflict` | `ActiveRecord::RecordNotUnique` | `Record already exists` |

> Para validações, `message` traz a lista de erros do model (`errors.full_messages.join(", ")`).

## Paginação

Listagens aceitam:

| Query param | Tipo | Default | Limite |
|---|---|---|---|
| `page` | int | `1` | — |
| `perPage` ou `per_page` | int | `10` | `50` |

A resposta inclui `pagination: { currentPage, nextPage, prevPage, totalPages, totalCount }`.

## Autenticação

Esquema: **Bearer JWT** via Devise-JWT (com revogação por JTI).

- Login: `POST /api/v1/login` retorna o token no header `Authorization: Bearer <token>`.
- Em requests autenticados, envie `Authorization: Bearer <token>` em todos os endpoints sob `/api/v1/...`, **exceto**:
  - `POST /api/v1/login`
  - `POST /api/v1/user` (signup)
  - `POST /api/v1/password` (forgot)
  - `PATCH /api/v1/password` (reset)
  - `POST /api/v1/inbound/messages` (webhook — autenticado por assinatura do provider)
  - `GET /health`
- `DELETE /api/v1/logout` revoga o JTI do token atual.
- Após `POST /api/v1/user`, o token também é retornado no header `Authorization`.

---

## Endpoints

### Auth & Sessão

#### `POST /api/v1/login`

Cria sessão e retorna JWT no header.

**Body**

```json
{
  "user": {
    "email": "alice@example.com",
    "password": "secret123"
  }
}
```

**200 OK**

Headers: `Authorization: Bearer <jwt>`

```json
{
  "success": true,
  "message": "Logged in successfully.",
  "data": {
    "user": {
      "id": "f1...",
      "name": "Alice",
      "email": "alice@example.com",
      "phone": "+5511999999999",
      "created_at": "...",
      "updated_at": "..."
    }
  }
}
```

**401 Unauthorized** — credenciais inválidas (`errorCode: 1001`).

---

#### `DELETE /api/v1/logout`

**Headers**: `Authorization: Bearer <jwt>` (obrigatório).

**200 OK**

```json
{ "success": true, "message": "Logged out successfully." }
```

---

### Usuário

#### `POST /api/v1/user`

Signup. **Não requer auth**. Token retornado no header.

**Body**

```json
{
  "user": {
    "name": "Alice",
    "email": "alice@example.com",
    "phone": "+5511999999999",
    "password": "secret123",
    "password_confirmation": "secret123"
  }
}
```

**201 Created**

Header: `Authorization: Bearer <jwt>`

```json
{
  "success": true,
  "message": "User created successfully.",
  "data": {
    "user": { "id": "f1...", "name": "Alice", "email": "alice@example.com", "phone": "...", "created_at": "...", "updated_at": "..." }
  }
}
```

**422** se a validação falhar (e-mail duplicado, senha fraca, etc.).

---

#### `GET /api/v1/user`

Retorna o usuário autenticado.

**200 OK**

```json
{
  "success": true,
  "data": {
    "user": { "id": "...", "name": "...", "email": "...", "phone": "...", "created_at": "...", "updated_at": "..." }
  }
}
```

---

### Senha

#### `POST /api/v1/password`

Solicita link de reset (envia e-mail; em dev usa MailDev em `:1080`). **Sem auth**.

**Body**

```json
{ "user": { "email": "alice@example.com" } }
```

**200 OK** — mesma resposta independentemente de o e-mail existir (proteção contra enumeração):

```json
{ "success": true, "message": "If the email exists, password reset instructions were sent." }
```

---

#### `PATCH /api/v1/password`

Aplica nova senha usando o token recebido por e-mail. **Sem auth**.

**Body**

```json
{
  "user": {
    "reset_password_token": "abc123...",
    "password": "novaSenha",
    "password_confirmation": "novaSenha"
  }
}
```

**200 OK**

```json
{ "success": true, "message": "Password reset successfully." }
```

**422** se token inválido/expirado ou senhas não conferem.

---

### Categorias

Recurso: `Financial::Category`.

#### `GET /api/v1/financial/categories`

Lista paginada, ordenada por `name ASC`.

**Query**: `page`, `perPage`.

**200 OK**

```json
{
  "success": true,
  "data": [
    { "id": "...", "name": "mercado" },
    { "id": "...", "name": "transporte" }
  ],
  "pagination": { "currentPage": 1, "nextPage": null, "prevPage": null, "totalPages": 1, "totalCount": 2 }
}
```

---

#### `GET /api/v1/financial/categories/:id`

```json
{
  "success": true,
  "data": { "id": "...", "name": "mercado" }
}
```

---

#### `POST /api/v1/financial/categories`

**Body**

```json
{ "category": { "name": "Saúde" } }
```

**201 Created**

```json
{ "success": true, "message": "Category created successfully.", "data": { "id": "...", "name": "Saúde" } }
```

---

#### `PATCH /api/v1/financial/categories/:id`

**Body**

```json
{ "category": { "name": "Saúde e bem-estar" } }
```

**200 OK** com a categoria atualizada.

---

#### `DELETE /api/v1/financial/categories/:id`

**200 OK**

```json
{ "success": true, "message": "Category deleted successfully." }
```

> Categorias com transações associadas não podem ser deletadas — retorna `422`.

---

### Transações

Recurso: `Financial::Transaction`.

Atributos permitidos (`PERMITTED_ATTRIBUTES`): `amount`, `transaction_type`, `description`, `occurred_at`, `category_id`, `metadata`.

#### `GET /api/v1/financial/transactions`

Lista paginada ordenada por `occurred_at DESC, created_at DESC`.

**Query**

| Param | Tipo | Descrição |
|---|---|---|
| `transaction_type` | `expense` \| `income` | Filtra por tipo |
| `category_id` | UUID | Filtra por categoria |
| `from` | data ISO | `occurred_at >= from` |
| `to` | data ISO | `occurred_at <= to` |
| `page`, `perPage` | int | Paginação |

**200 OK** — view `:default` (sem `metadata`/`artifact_id`/`category` aninhado).

```json
{
  "success": true,
  "data": [
    {
      "id": "...",
      "amount": "50.0",
      "transaction_type": "expense",
      "description": "mercado",
      "occurred_at": "2026-05-24T18:00:00Z",
      "category_id": "..."
    }
  ],
  "pagination": { "currentPage": 1, "nextPage": null, "prevPage": null, "totalPages": 1, "totalCount": 1 }
}
```

---

#### `GET /api/v1/financial/transactions/:id`

View `:extended` (inclui `metadata`, `artifact_id`, `created_at`, `updated_at`, `budget_warnings` e a `category` aninhada).

```json
{
  "success": true,
  "data": {
    "id": "...",
    "amount": "50.0",
    "transaction_type": "expense",
    "description": "mercado",
    "occurred_at": "2026-05-24T18:00:00Z",
    "category_id": "...",
    "metadata": { "source": "chat" },
    "artifact_id": null,
    "created_at": "...",
    "updated_at": "...",
    "budget_warnings": [
      { "budget_id": "...", "period_type": "monthly", "usage_percent": 87.5 }
    ],
    "category": { "id": "...", "name": "mercado" }
  }
}
```

> `budget_warnings` é populado pelo use case quando a transação consome ≥ X% de um orçamento ativo.

---

#### `POST /api/v1/financial/transactions`

**Body**

```json
{
  "transaction": {
    "amount": 49.9,
    "transaction_type": "expense",
    "description": "Padaria",
    "occurred_at": "2026-05-24T07:30:00Z",
    "category_id": "ac3...",
    "metadata": { "tags": ["café"] }
  }
}
```

**201 Created** — view `:extended`.

**Erros**

- `422` quando `amount <= 0`, `transaction_type` ausente etc.

---

#### `PATCH /api/v1/financial/transactions/:id`

Mesmo body do `POST` (campos opcionais). **200 OK** com a transação atualizada.

---

#### `DELETE /api/v1/financial/transactions/:id`

```json
{ "success": true, "message": "Transaction deleted successfully." }
```

---

### Orçamentos

Recurso: `Financial::Budget`.

Atributos permitidos: `period_type`, `period_start`, `period_end`, `limit_amount`.

`period_type` ∈ `weekly`, `monthly`, `yearly`, `custom`.

> O par `(user_id, period_start, period_end)` é único.

#### `GET /api/v1/financial/budgets`

Lista paginada ordenada por `period_start DESC`.

**Query**

| Param | Tipo | Descrição |
|---|---|---|
| `period_type` | `weekly`/`monthly`/`yearly`/`custom` | Filtro |
| `page`, `perPage` | int | Paginação |

**200 OK** — view `:default`.

```json
{
  "success": true,
  "data": [
    {
      "id": "...",
      "period_type": "monthly",
      "period_start": "2026-05-01",
      "period_end": "2026-05-31",
      "limit_amount": "2000.00"
    }
  ],
  "pagination": { "...": "..." }
}
```

---

#### `GET /api/v1/financial/budgets/:id`

View `:extended` — inclui consumo:

```json
{
  "success": true,
  "data": {
    "id": "...",
    "period_type": "monthly",
    "period_start": "2026-05-01",
    "period_end": "2026-05-31",
    "limit_amount": "2000.00",
    "spent_amount": "1240.50",
    "remaining": "759.50",
    "usage_percent": 62.03,
    "created_at": "...",
    "updated_at": "..."
  }
}
```

---

#### `GET /api/v1/financial/budgets/current`

Retorna **todos os orçamentos cobrindo a data informada** (default: hoje).

**Query**: `date` (ISO `YYYY-MM-DD`, opcional).

**200 OK** — array em `data` + `metadata.reference_date`:

```json
{
  "success": true,
  "data": [ { "...": "view :extended" } ],
  "metadata": { "reference_date": "2026-05-24" }
}
```

---

#### `POST /api/v1/financial/budgets`

**Body**

```json
{
  "budget": {
    "period_type": "monthly",
    "period_start": "2026-06-01",
    "period_end": "2026-06-30",
    "limit_amount": 2500.00
  }
}
```

**201 Created** — view `:extended`.

**422** se `period_end <= period_start`, `limit_amount <= 0`, ou conflito de unicidade `(period_start, period_end)`.

---

#### `PATCH /api/v1/financial/budgets/:id`

Mesmo body. **200 OK** com o orçamento atualizado.

---

#### `DELETE /api/v1/financial/budgets/:id`

```json
{ "success": true, "message": "Budget deleted successfully." }
```

---

### Resumo financeiro

#### `GET /api/v1/financial/summary`

Agrega receitas, despesas, totais e quebra por categoria/tipo dentro de um intervalo.

**Query**

| Param | Tipo | Default |
|---|---|---|
| `from` | data | início do mês corrente |
| `to` | data | fim do mês corrente |
| `transaction_type` | `expense`/`income` | — |
| `category_id` | UUID | — |

**200 OK**

```json
{
  "success": true,
  "data": {
    "total_amount": "1840.50",
    "transaction_count": 23,
    "by_type": { "expense": "1240.50", "income": "600.00" },
    "by_category": [
      { "category_id": "...", "category_name": "mercado",     "amount": "650.30" },
      { "category_id": "...", "category_name": "transporte",  "amount": "180.00" },
      { "category_id": null,  "category_name": "Uncategorized", "amount": "60.00" }
    ]
  },
  "metadata": { "from": "2026-05-01", "to": "2026-05-31" }
}
```

---

### Artefatos (recibos)

Recurso: `Artifact`. Upload de imagem que dispara OCR via Gemini e cria transação automaticamente quando a confiança supera o threshold (`OCR_CONFIDENCE_THRESHOLD`).

`status`: `pending`, `processed`, `failed`, `needs_review`.

#### `GET /api/v1/artifacts`

Lista paginada ordenada por `created_at DESC` — view `:default`.

```json
{
  "success": true,
  "data": [
    {
      "id": "...",
      "artifact_type": "receipt",
      "status": "processed",
      "source": "manual",
      "occurred_at": "2026-05-24T13:00:00Z",
      "created_at": "...",
      "updated_at": "..."
    }
  ],
  "pagination": { "...": "..." }
}
```

---

#### `GET /api/v1/artifacts/:id`

View `:extended` — inclui `file_url` (path relativo do Active Storage) e `processed_data` com a estrutura extraída pelo OCR.

```json
{
  "success": true,
  "data": {
    "id": "...",
    "artifact_type": "receipt",
    "status": "processed",
    "source": "manual",
    "occurred_at": "...",
    "created_at": "...",
    "updated_at": "...",
    "file_url": "/rails/active_storage/blobs/redirect/.../receipt.jpg",
    "processed_data": {
      "amount": "49.90",
      "transaction_type": "expense",
      "description": "Padaria do João",
      "metadata": { "items": [ { "name": "café", "qty": 1 } ] }
    }
  }
}
```

---

#### `POST /api/v1/artifacts`

**Content-Type**: `multipart/form-data`.

**Form fields**

| Campo | Tipo | Descrição |
|---|---|---|
| `file` | file | Imagem do recibo (jpeg/png) |
| `artifact_type` | string | Tipicamente `"receipt"` |
| `source` | string | Origem (`"manual"`, `"whatsapp"`, etc.) |

**202 Accepted** — view `:extended`. O OCR roda em background; o front deve fazer polling em `GET /api/v1/artifacts/:id` ou aguardar status `processed`/`needs_review`.

```json
{
  "success": true,
  "message": "Artifact uploaded; OCR processing queued.",
  "data": { "id": "...", "status": "pending", "...": "..." }
}
```

---

### Chat — Conversas

Recurso: `Chat::Conversation`.

Listagem retorna apenas conversas **ativas** (não arquivadas).

#### `GET /api/v1/chat/conversations`

View `:default`. Ordenado por `updated_at DESC`.

```json
{
  "success": true,
  "data": [
    {
      "id": "...",
      "title": "Gastos de maio",
      "archived_at": null,
      "created_at": "...",
      "updated_at": "..."
    }
  ],
  "pagination": { "...": "..." }
}
```

---

#### `GET /api/v1/chat/conversations/:id`

View `:extended` — inclui `messages_count`.

```json
{
  "success": true,
  "data": {
    "id": "...",
    "title": "Gastos de maio",
    "archived_at": null,
    "created_at": "...",
    "updated_at": "...",
    "messages_count": 14
  }
}
```

---

#### `POST /api/v1/chat/conversations`

**Body**

```json
{ "title": "Conversa de teste" }
```

**201 Created** — view `:default`:

```json
{
  "success": true,
  "message": "Conversation created.",
  "data": { "id": "...", "title": "Conversa de teste", "archived_at": null, "created_at": "...", "updated_at": "..." }
}
```

---

#### `DELETE /api/v1/chat/conversations/:id`

Soft archive (seta `archived_at`).

```json
{ "success": true, "message": "Conversation archived." }
```

---

### Chat — Mensagens

Recurso: `Chat::Message`. Mensagens deletadas (soft delete por `deleted_at`) **não** aparecem em `index`/`show`.

Campos:

| Campo | Tipo | Descrição |
|---|---|---|
| `role` | `user` \| `assistant` \| `system` | Quem enviou |
| `kind` | `text` \| `audio` | Texto ou áudio |
| `body` | string | Texto da mensagem (para áudio, é a transcrição quando processada) |
| `status` | `pending` \| `processing` \| `completed` \| `failed` | Estado do pipeline |
| `intent` | string \| null | Intent classificado (ex.: `create_transaction`, `query_balance`, `unknown`) |
| `parent_message_id` | UUID \| null | Para mensagens do assistente, aponta para a mensagem do usuário |
| `payload` (extended) | object | Detalhes do processamento (`transaction_id`, `category_id`, `confidence`, etc.) |
| `error` (extended) | object \| null | `{ class, message }` quando `status: "failed"` |
| `audio_url` (extended) | string \| null | Path do anexo de áudio |

#### `GET /api/v1/chat/conversations/:conversation_id/messages`

View `:default`. Ordenado por `created_at ASC`. Paginado.

```json
{
  "success": true,
  "data": [
    {
      "id": "...",
      "role": "user",
      "kind": "text",
      "body": "gastei 50 no mercado",
      "status": "completed",
      "intent": "create_transaction",
      "conversation_id": "...",
      "parent_message_id": null,
      "created_at": "...",
      "updated_at": "..."
    },
    {
      "id": "...",
      "role": "assistant",
      "kind": "text",
      "body": "Despesa registrada: R$50,00 - mercado [mercado]",
      "status": "completed",
      "intent": "create_transaction",
      "conversation_id": "...",
      "parent_message_id": "...",
      "created_at": "...",
      "updated_at": "..."
    }
  ],
  "pagination": { "...": "..." }
}
```

---

#### `GET /api/v1/chat/conversations/:conversation_id/messages/:id`

View `:extended` — inclui `payload`, `error`, `audio_url`.

```json
{
  "success": true,
  "data": {
    "id": "...",
    "role": "assistant",
    "kind": "text",
    "body": "Despesa registrada: R$50,00 - mercado [mercado]",
    "status": "completed",
    "intent": "create_transaction",
    "conversation_id": "...",
    "parent_message_id": "...",
    "created_at": "...",
    "updated_at": "...",
    "payload": {
      "transaction_id": "...",
      "category_id": "...",
      "confidence": 0.92,
      "intent_confidence": 0.95,
      "transcription": null
    },
    "error": null,
    "audio_url": null
  }
}
```

---

#### `POST /api/v1/chat/conversations/:conversation_id/messages`

Cria a mensagem do usuário e dispara o pipeline assíncrono. O front recebe **imediatamente** a mensagem com `status: "pending"` e deve fazer polling (ou WebSocket no futuro) para acompanhar `status` e a resposta do assistente.

**Content-Type**:
- `application/json` para texto.
- `multipart/form-data` para áudio (com ou sem texto).

**Form / Body fields**

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `body` | string | sim* | Texto da mensagem |
| `audio` | file | sim* | Arquivo de áudio anexado |
| `client_message_id` | UUID | não | UUID gerado no client para idempotência |

*Pelo menos um entre `body` e `audio` é obrigatório.

**202 Accepted** — view `:extended`.

```json
{
  "success": true,
  "message": "Message queued for processing.",
  "data": {
    "id": "...",
    "role": "user",
    "kind": "text",
    "body": "gastei 50 no mercado",
    "status": "pending",
    "intent": null,
    "conversation_id": "...",
    "parent_message_id": null,
    "created_at": "...",
    "updated_at": "...",
    "payload": null,
    "error": null,
    "audio_url": null
  }
}
```

**Idempotência**: se o mesmo `client_message_id` for reenviado pelo mesmo usuário, a API retorna a mensagem original (sem duplicar o pipeline).

---

#### Como o front-end consome o pipeline do chat

1. `POST` cria a mensagem do usuário com `status: "pending"`.
2. Em background, `Chat::ProcessMessageJob` roda:
   - Se `kind: "audio"`, transcreve e atualiza `body`.
   - Classifica o intent → `create_transaction`, `create_budget`, `create_category`, `create_installment`, `query_balance`, `query_budget` ou `unknown`.
   - Executa o handler correspondente (chama use cases reais — cria transação/orçamento/categoria/parcelamento ou consulta saldo/orçamento).
   - Cria a **mensagem do assistente** (uma nova `Chat::Message` com `role: "assistant"` e `parent_message_id` apontando pra mensagem do usuário) com a resposta formatada.
   - Atualiza a mensagem do usuário para `status: "completed"` (ou `"failed"`).
3. O front faz polling em:
   - `GET /api/v1/chat/conversations/:conversation_id/messages` (com filtro por data se quiser apenas as novas), **ou**
   - `GET /api/v1/chat/conversations/:conversation_id/messages/:id` para checar a mensagem específica.

A mensagem do assistente conterá:
- `body`: texto pronto para exibir.
- `payload.transaction_id`, `payload.budget_id`, `payload.category_id`, `payload.installment_id`: ids dos recursos criados.
- `payload.confidence`: confiança da extração.
- `payload.intent_confidence`: confiança do classificador.
- `payload.transcription`: dados da transcrição quando o original era áudio.

---

### Inbound (webhook)

#### `POST /api/v1/inbound/messages`

Endpoint de **webhook** para mensagens externas (Twilio/WhatsApp). O front-end **não chama esse endpoint**; ele é validado pela assinatura do provider.

- Sucesso: `204 No Content` (mais especificamente, `head :ok`).
- Falha de assinatura: `401 Unauthorized` com `errorCode: 1001`.

---

### Healthcheck

#### `GET /health`

Resposta livre — útil para liveness/readiness probes.

---

## Tipos e enums

### Transaction

```ts
type TransactionType = "expense" | "income";

interface Transaction {
  id: string;                 // uuid
  amount: string;             // decimal "10.00"
  transaction_type: TransactionType;
  description: string | null;
  occurred_at: string;        // ISO-8601
  category_id: string | null;
  // view extended:
  metadata?: Record<string, unknown> | null;
  artifact_id?: string | null;
  budget_warnings?: BudgetWarning[];
  category?: { id: string; name: string } | null;
  created_at?: string;
  updated_at?: string;
}

interface BudgetWarning {
  budget_id: string;
  period_type: BudgetPeriodType;
  usage_percent: number;
}
```

### Budget

```ts
type BudgetPeriodType = "weekly" | "monthly" | "yearly" | "custom";

interface Budget {
  id: string;
  period_type: BudgetPeriodType;
  period_start: string;       // YYYY-MM-DD
  period_end: string;         // YYYY-MM-DD
  limit_amount: string;       // decimal
  // view extended:
  spent_amount?: string;
  remaining?: string;
  usage_percent?: number;
  created_at?: string;
  updated_at?: string;
}
```

### Category

```ts
interface Category {
  id: string;
  name: string;
  // view extended:
  created_at?: string;
  updated_at?: string;
}
```

### Summary

```ts
interface Summary {
  total_amount: string;
  transaction_count: number;
  by_type: { expense: string; income: string };
  by_category: Array<{
    category_id: string | null;
    category_name: string;     // "Uncategorized" quando null
    amount: string;
  }>;
}
```

### Artifact

```ts
type ArtifactStatus = "pending" | "processed" | "failed" | "needs_review";

interface Artifact {
  id: string;
  artifact_type: string;       // ex.: "receipt"
  status: ArtifactStatus;
  source: string | null;
  occurred_at: string | null;
  created_at: string;
  updated_at: string;
  // view extended:
  file_url?: string | null;
  processed_data?: Record<string, unknown> | null;
}
```

### Chat

```ts
type ChatRole = "user" | "assistant" | "system";
type ChatKind = "text" | "audio";
type ChatStatus = "pending" | "processing" | "completed" | "failed";
type ChatIntent =
  | "create_transaction"
  | "create_budget"
  | "create_category"
  | "create_installment"
  | "query_balance"
  | "query_budget"
  | "unknown"
  | null;

interface ChatConversation {
  id: string;
  title: string | null;
  archived_at: string | null;
  created_at: string;
  updated_at: string;
  // view extended:
  messages_count?: number;
}

interface ChatMessage {
  id: string;
  conversation_id: string;
  parent_message_id: string | null;
  role: ChatRole;
  kind: ChatKind;
  body: string | null;
  status: ChatStatus;
  intent: ChatIntent;
  created_at: string;
  updated_at: string;
  // view extended:
  payload?: ChatMessagePayload | null;
  error?: { class: string; message: string } | null;
  audio_url?: string | null;
}

interface ChatMessagePayload {
  transaction_id?: string;
  budget_id?: string;
  category_id?: string;
  installment_id?: string;
  confidence?: number;
  intent_confidence?: number;
  transcription?: { confidence?: number; provider?: string; model?: string } | null;
  // outros campos retornados por handlers de query (ex.: by_type, budgets, etc.)
}
```

### User

```ts
interface User {
  id: string;
  name: string;
  email: string;
  phone: string | null;
  created_at: string;
  updated_at: string;
}
```

---

## Apêndice — exemplo de cliente HTTP (TypeScript)

```ts
const BASE_URL = "http://localhost:3000";
const token = localStorage.getItem("findu_token");

async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
  const res = await fetch(`${BASE_URL}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(init.headers ?? {}),
    },
  });

  const json = await res.json();
  if (!json.success) {
    throw new ApiError(json.message, json.errorCode, res.status);
  }
  return json as T;
}

class ApiError extends Error {
  constructor(message: string, public code: number, public status: number) {
    super(message);
  }
}
```

Login + persistência do token:

```ts
const res = await fetch(`${BASE_URL}/api/v1/login`, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ user: { email, password } }),
});

const auth = res.headers.get("Authorization") ?? "";
const token = auth.replace(/^Bearer\s+/, "");
localStorage.setItem("findu_token", token);
```

Upload de áudio (chat):

```ts
const form = new FormData();
form.append("audio", file);                 // File/Blob
form.append("client_message_id", crypto.randomUUID());

await fetch(`${BASE_URL}/api/v1/chat/conversations/${conversationId}/messages`, {
  method: "POST",
  headers: { Authorization: `Bearer ${token}` },
  body: form,
});
```
