# Findu — ActionCable (Realtime / Chat Streaming)

Como o realtime do Findu funciona, como desenvolver sem cair nas armadilhas conhecidas, boas práticas e como configurar para deploy / CI.

Base local: WebSocket em `ws://localhost:3000/cable`

---

## Sumário

- [Visão geral da arquitetura](#visão-geral-da-arquitetura)
- [A armadilha nº 1: adapter `async` vs `redis`](#a-armadilha-nº-1-adapter-async-vs-redis)
- [Configuração por ambiente](#configuração-por-ambiente)
- [Conexão e autenticação](#conexão-e-autenticação)
- [Canais e broadcast](#canais-e-broadcast)
- [Protocolo de eventos do chat](#protocolo-de-eventos-do-chat)
- [Consumidor no front-end](#consumidor-no-front-end)
- [Boas práticas de implementação](#boas-práticas-de-implementação)
- [Como testar (cliente WebSocket via bash)](#como-testar-cliente-websocket-via-bash)
- [Deploy e produção](#deploy-e-produção)
- [GitHub Actions / CI](#github-actions--ci)
- [Checklist de troubleshooting](#checklist-de-troubleshooting)

---

## Visão geral da arquitetura

O fluxo de uma mensagem do chat atravessa **três processos diferentes**:

```
Browser (Next.js)
   │  1. POST /api/v1/chat/conversations/:id/messages
   ▼
web  (Puma)  ──── cria a mensagem do usuário, faz o 1º broadcast,
   │               enfileira o job e segura a conexão WebSocket
   │  2. enqueue Chat::ProcessMessageJob
   ▼
sidekiq  ──── processa: transcrição/recibo → LLM (streaming) →
   │           broadcasts do assistente (bolha vazia, deltas, finalize)
   │
   ▼
Redis  ──── pub/sub: entrega os broadcasts do sidekiq de volta ao
   │         processo web, que os envia pela conexão WebSocket
   ▼
Browser  ──── recebe os frames e renderiza em tempo real
```

Pontos-chave:

- **As conexões WebSocket vivem no processo `web` (Puma).** É ele quem entrega frames ao browser.
- **A maior parte dos broadcasts do chat nasce no `sidekiq`** (`Chat::ProcessMessageJob` → `UseCase::Chat::AnswerConversationallyUseCase`), que é um **processo separado**.
- Para um broadcast feito no `sidekiq` chegar numa conexão segurada pelo `web`, o ActionCable precisa de um **backend pub/sub compartilhado entre processos** — ou seja, **Redis**.

---

## A armadilha nº 1: adapter `async` vs `redis`

O adapter `async` do ActionCable é **in-process**: um broadcast só alcança assinantes do **mesmo processo**.

Com `async` neste setup:

- A mensagem do usuário **aparecia** (o broadcast do `create` roda dentro do `web`/Puma, no POST).
- O streaming do assistente **não aparecia** (broadcastado pelo `sidekiq`; o `async` não cruza processos). Só surgia após reload, porque o reload relê do banco.

**Regra:** sempre que um broadcast puder nascer fora do processo web (Sidekiq, `rails runner`, rake, outro container), o adapter precisa ser `redis`. No Findu isso vale para **todos** os ambientes com chat — inclusive desenvolvimento.

`config/cable.yml`:

```yaml
development:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/0" } %>
  channel_prefix: findu_development

test:
  adapter: test

production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } %>
  channel_prefix: findu_production
```

- `test` usa `adapter: test` de propósito — os specs verificam broadcasts em memória, sem Redis.
- `channel_prefix` isola os canais por ambiente quando o mesmo Redis é compartilhado. Use prefixos distintos por ambiente.

---

## Configuração por ambiente

| Item | Onde | Observação |
|------|------|------------|
| Adapter | `config/cable.yml` | `redis` em dev e prod; `test` em teste |
| URL do Redis | `REDIS_URL` | `web` e `sidekiq` devem apontar para o **mesmo** Redis |
| Mount path | default `/cable` | não há mount custom em `routes.rb`; é o padrão do Rails |
| Forgery protection | `config/environments/development.rb` | `config.action_cable.disable_request_forgery_protection = true` (apenas dev) |
| Origens permitidas | `config/environments/production.rb` | `config.action_cable.allowed_request_origins` (ver deploy) |
| Worker pool | `config/application.rb` | `config.action_cable.worker_pool_size` via `ACTION_CABLE_WORKER_POOL_SIZE` (default 4) |
| Pool do banco | `config/database.yml` | `DB_POOL` ou, por padrão, `RAILS_MAX_THREADS + ACTION_CABLE_WORKER_POOL_SIZE` |
| Cache | `config/environments/production.rb` | `:redis_cache_store` (compartilhado entre `web` e `sidekiq`) |

> **Dimensionamento do pool (importante):** o ActionCable processa callbacks de canal num pool próprio (`worker_pool_size`), separado das threads do Puma. O `subscribed` faz query no banco, então o pool do ActiveRecord precisa cobrir **Puma + cable workers** — senão dá `ActiveRecord::ConnectionTimeoutError` sob carga. O `database.yml` já soma os dois por padrão.

No `docker-compose.yml`, `web` e `sidekiq` já compartilham `REDIS_URL: redis://redis:6379/0`.

---

## Conexão e autenticação

A conexão é autenticada por **JWT**, passado como query param `token` (ou header `Authorization: Bearer`). Ver `app/channels/application_cable/connection.rb`:

- Extrai o token de `params[:token]`, `params[:access_token]` ou do header `Authorization`.
- Decodifica com `HS256` usando `ENV["DEVISE_JWT_SECRET_KEY"]` (fallback `secret_key_base`).
- Valida `payload["sub"]` (id do usuário) e `payload["jti"]` contra `user.jti`.
- `reject_unauthorized_connection` em qualquer falha.

O front passa o token na URL porque a API de WebSocket do browser não permite headers customizados no handshake. Ver `src/infrastructure/cable.client.ts` no front.

> Em desenvolvimento, `disable_request_forgery_protection = true` evita rejeição por origem. Em produção isso **não** vale — configure `allowed_request_origins` (ver deploy).

---

## Canais e broadcast

Canal: `app/channels/chat/conversation_channel.rb`

```ruby
class Chat::ConversationChannel < ApplicationCable::Channel
  def subscribed
    conversation = current_user.chat_conversations.find_by(id: params[:conversation_id])
    return reject unless conversation
    stream_for conversation
  end

  def unsubscribed
    stop_all_streams
  end
end
```

- `stream_for conversation` cria um stream isolado por conversa.
- O `find_by` escopado em `current_user` garante isolamento: um usuário só assina conversas próprias.

Broadcast: `app/models/chat/conversation.rb`

- `broadcast_message!(message)` → snapshot completo e autoritativo (`message.upserted`), serializado pelo `MessageSerializer`. Usado na criação, mudança de status e finalização.
- `broadcast_delta!(message_id, delta)` → evento leve (`message.delta`) só com o pedaço novo de texto. Sem DB e sem serializer, para poder ser emitido muitas vezes por segundo.

---

## Protocolo de eventos do chat

Todo frame tem a forma `{ type, message }`.

| `type` | `message` | Significado |
|--------|-----------|-------------|
| `message.upserted` | objeto `ChatMessage` completo | Estado autoritativo. O cliente faz **upsert por `id`** (cria ou substitui). |
| `message.delta` | `{ id, delta }` | Pedaço incremental do corpo. O cliente **concatena** o `delta` no body daquela mensagem. |

Sequência típica de um turno:

```
message.upserted  (user, status: processing)
message.upserted  (user, status: completed)
message.upserted  (assistant, status: processing, body: "")   ← bolha vazia → "digitando…"
message.delta     (assistant, "Um orçamento é...")
message.delta     (assistant, " ...em ordem.")
message.upserted  (assistant, status: completed, body completo) ← reconcilia tudo
```

O `message.upserted` final é a **fonte da verdade**: se algum `delta` se perder ou chegar fora de ordem, ele corrige.

---

## Consumidor no front-end

O chat **não** usa React Query para as mensagens — usa estado local do React alimentado pela subscription. Isso evita problemas de cache/observer entre instâncias de QueryClient.

- `src/infrastructure/cable.client.ts` — singleton do consumer; reconstrói se o token mudar; retorna `null` se ainda não houver token.
- `src/features/chat/hooks/useConversationMessages.ts`:
  - Carga inicial: um `listMessages` (fetch único) ao abrir a conversa.
  - Realtime: assina o canal; `message.upserted` faz upsert por `id`, `message.delta` concatena no body.
  - **Retry da subscription** enquanto o consumer (token) não está pronto — sem isso a aba pode ficar sem assinar.
- `src/features/chat/hooks/useSendMessage.ts` — `POST` simples + estado `isSending`. A mensagem criada volta pelo cable, não por refetch.

> Não invalidar/refetchar a lista a cada envio: como o corpo do assistente só é persistido no finalize, um refetch no meio do stream traria `body: ""` e apagaria o que já streamou.

---

## Boas práticas de implementação

- **Delta para transporte, snapshot para verdade.** Stream com eventos leves (`message.delta`); persista uma vez no finalize e mande um `message.upserted` autoritativo.
- **Não persista a cada chunk.** Gravar no banco por chunk gera I/O desnecessário; acumule em memória e grave no fim.
- **Broadcast de delta sem serializer.** Não chame o serializer (que dispara queries de attachment) no caminho quente do streaming.
- **Upsert idempotente por `id` no cliente.** O mesmo `id` pode chegar várias vezes (processing → completed); sempre faça merge por `id`.
- **Isolamento de canal.** Sempre escope o `stream_for`/`find_by` no `current_user`. Nunca confie só no `conversation_id` vindo do cliente.
- **Throttle do streaming.** Emita deltas em janelas curtas (ex.: ~80ms) para fluidez sem floodar o WebSocket.
- **Payload enxuto.** Mantenha os frames pequenos; evite mandar dados pesados que não mudam a cada delta.

---

## Como testar (cliente WebSocket via bash)

Para validar a entrega de frames **independente do front**, conecte um cliente WebSocket cru. Node 22+ tem `WebSocket` e `fetch` globais (sem precisar do pacote `ws`).

1. Forje um JWT válido para o cable dentro do container `web` (mesmo segredo do servidor):

```bash
docker compose exec -T web bin/rails runner '
user = User.find("<USER_ID>")
secret = ENV.fetch("DEVISE_JWT_SECRET_KEY") { Rails.application.secret_key_base }
puts JWT.encode({ "sub" => user.id, "jti" => user.jti, "exp" => Time.now.to_i + 3600 }, secret, "HS256")
'
```

> Esse token serve para o **cable**. A API REST usa outro caminho de auth e pode rejeitá-lo (401) — por isso, dispare a mensagem via `rails runner` (abaixo), não via POST.

2. Cliente listener (`cable_test.mjs`):

```js
const TOKEN = process.env.TOKEN;
const CONV = process.env.CONV;
const ws = new WebSocket(`ws://localhost:3000/cable?token=${encodeURIComponent(TOKEN)}`);
const identifier = JSON.stringify({ channel: "Chat::ConversationChannel", conversation_id: CONV });
const t0 = Date.now();
const log = (...a) => console.log(`+${Date.now() - t0}ms`, ...a);

ws.addEventListener("message", (evt) => {
  const data = JSON.parse(evt.data);
  if (data.type === "welcome") return ws.send(JSON.stringify({ command: "subscribe", identifier }));
  if (data.type === "ping" || data.type === "confirm_subscription") return;
  if (data.message) log(data.message.type, JSON.stringify(data.message.message ?? data.message).slice(0, 80));
});
setTimeout(() => process.exit(0), 30000);
```

3. Rode o listener e dispare uma resposta por outro processo (prova o cross-process):

```bash
TOKEN='...' CONV='<CONV_ID>' node cable_test.mjs &
sleep 3
docker compose exec -T web bin/rails runner '
conv = Chat::Conversation.find("<CONV_ID>")
msg = conv.messages.create!(user: conv.user, role: "user", kind: "text", status: "pending", body: "Teste")
UseCase::Chat::ProcessMessageUseCase.new.call(message: msg)
'
wait
```

Com adapter `redis`, o listener recebe `message.upserted` e `message.delta`. Com `async`, recebe **zero frames** — exatamente o sintoma do bug original.

---

## Deploy e produção

- **Redis obrigatório e compartilhado.** `web` e os workers (`sidekiq`) devem usar o **mesmo** `REDIS_URL`. Sem isso, não há streaming.
- **Origens permitidas.** Em produção, configure em `config/environments/production.rb`:

  ```ruby
  config.action_cable.allowed_request_origins = [ENV.fetch("FRONTEND_ORIGIN")]
  # aceita regex também: [/https:\/\/.*\.findu\.app/]
  ```

  Não deixar comentado: por padrão o ActionCable só aceita same-origin, e o front em outro domínio será rejeitado no handshake.
- **URL pública do WebSocket.** Se o cable estiver atrás de proxy/domínio próprio, defina `config.action_cable.url = "wss://api.seu-dominio/cable"` e garanta que o front aponte para a mesma origem (`NEXT_PUBLIC_API_BASE_URL`).
- **Proxy precisa de upgrade WebSocket.** Nginx/ALB/Cloudflare devem encaminhar `Upgrade`/`Connection` e ter timeout de idle alto o suficiente:

  ```nginx
  location /cable {
    proxy_pass http://app;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 3600s;
  }
  ```

- **Escala horizontal.** Com Redis como backend, múltiplos processos/instâncias do `web` funcionam sem sticky sessions para o pub/sub (qualquer instância entrega o broadcast). Avalie `worker`/`thread` do Puma para o volume de conexões simultâneas.
- **CORS ≠ ActionCable origins.** `config/initializers/cors.rb` (hoje `origins "*"`, expõe `Authorization`) controla o REST. O WebSocket é controlado por `allowed_request_origins`. Ajuste os dois em produção.
- **TLS.** Em produção use `wss://`. O `cable.client.ts` já deriva `wss` quando a base é `https`.

---

## GitHub Actions / CI

- **Testes não precisam de Redis.** O ambiente `test` usa `adapter: test`; os specs verificam broadcasts em memória. Não suba serviço Redis só para isso.
- **Se algum teste de integração exigir Redis** (ex.: Sidekiq inline com cable real), adicione o serviço ao job:

  ```yaml
  services:
    redis:
      image: redis:7-alpine
      ports: ["6379:6379"]
      options: >-
        --health-cmd "redis-cli ping" --health-interval 10s
        --health-timeout 5s --health-retries 5
  env:
    REDIS_URL: redis://localhost:6379/0
  ```

- **Segredos no deploy.** Garanta `DEVISE_JWT_SECRET_KEY`, `REDIS_URL` e `FRONTEND_ORIGIN` definidos no ambiente de deploy (não no CI de testes).
- **Smoke test pós-deploy (opcional).** O script de cliente WebSocket acima pode rodar contra o ambiente de staging para validar que o handshake e o streaming sobem após o deploy.

---

## Checklist de troubleshooting

Mensagem do usuário aparece, mas o assistente não streama (só após reload):
- [ ] `config/cable.yml` está em `adapter: redis` no ambiente atual? (não `async`)
- [ ] `web` e `sidekiq` apontam para o **mesmo** `REDIS_URL`?
- [ ] Reiniciou `web` e `sidekiq` após mudar o `cable.yml`?

Nada chega ao cliente (nem a mensagem do usuário):
- [ ] O handshake do WebSocket sobe? (DevTools → Network → WS) — senão, token/origem.
- [ ] Em produção, `allowed_request_origins` inclui a origem do front?
- [ ] O proxy encaminha o upgrade de WebSocket?

Frame chega mas a UI não muda:
- [ ] O cliente faz upsert por `id` e concatena `delta` no estado que a UI renderiza?
- [ ] Não há refetch/invalidação apagando o corpo streamado no meio do caminho?
