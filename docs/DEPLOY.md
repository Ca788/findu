# Guia de Deploy — Stack Free Tier

Documento de referência para deployar este projeto (ou projetos similares Rails + Next.js) na seguinte stack 100% grátis:

```
Vercel       (Next.js front-end)
Fly.io       (Rails API + Sidekiq worker)
Supabase     (PostgreSQL + Object Storage S3-compatível)
Upstash      (Redis com TLS)
```

---

## 1. Arquitetura

```
                ┌──────────────────────────┐
   Browser ─►   │  Vercel (Next.js)        │  https://*.vercel.app
                └────────┬─────────────────┘
                         │ HTTPS (axios)
                         │ WSS    (Action Cable)
                         ▼
                ┌──────────────────────────┐
                │  Fly.io app "findu-api"  │  https://findu-api.fly.dev
                │ ┌────────────┬─────────┐ │
                │ │ web (Puma) │ worker  │ │
                │ │            │(Sidekiq)│ │
                │ └─────┬──────┴────┬────┘ │
                └───────┼───────────┼──────┘
            ┌───────────┘           └─────────────┐
            ▼                                      ▼
   ┌────────────────┐                     ┌─────────────────┐
   │   Supabase     │                     │   Upstash       │
   │ • Postgres 17  │                     │ • Redis (TLS)   │
   │ • Storage S3   │                     │   - Action Cable│
   └────────────────┘                     │   - Sidekiq     │
                                          │   - Rails cache │
                                          └─────────────────┘
```

---

## 2. Pré-requisitos

Antes de começar, ter conta em:

| Serviço | Para que |
|---|---|
| [github.com](https://github.com) | Repositórios (back e front) |
| [fly.io](https://fly.io) | Backend Rails (web + worker) |
| [supabase.com](https://supabase.com) | Postgres + Object Storage |
| [upstash.com](https://upstash.com) | Redis (Action Cable + Sidekiq) |
| [vercel.com](https://vercel.com) | Frontend Next.js |

CLIs e ferramentas locais:

```bash
# Fly CLI
curl -L https://fly.io/install.sh | sh
export PATH="$HOME/.fly/bin:$PATH"
flyctl version

# psql (validar conexão Postgres antes de deploy)
sudo apt-get install postgresql-client   # Debian/Ubuntu

# Docker (opcional, pra build local)
sudo apt-get install docker.io
```

---

## 3. Setup passo a passo

### 3.1 Supabase (Postgres + Storage)

1. **Criar projeto** em [app.supabase.com](https://app.supabase.com/projects).
2. **Pegar a DATABASE_URL**:
   - Settings → Database → Connection string → aba **Session pooler** (porta 5432).
   - Formato esperado:
     ```
     postgresql://postgres.<PROJECT_REF>:<PASSWORD>@aws-0-<REGION>.pooler.supabase.com:5432/postgres
     ```
   - Se o pooler falhar com `tenant/user not found`, usar **Direct connection** (`db.<PROJECT_REF>.supabase.co:5432`) como fallback (limite 60 conexões).
   - Adicionar `?sslmode=require` no final.
3. **Criar bucket de Storage**:
   - Storage → New bucket → nome (ex: `findu-storage`) → Private.
4. **Habilitar S3 Connection**:
   - Storage → Settings (engrenagem) → aba S3 Connection.
   - "Enable S3 connection" → New access key.
   - **Copiar `Access Key ID` e `Secret Access Key` AGORA** (o secret não aparece depois).
5. **Anotar**:
   - `PROJECT_REF` (extrai da URL do projeto Supabase, ex: `ofnqxcowdokluupklolj`)
   - `Region` do storage (ex: `us-west-2`)
   - Nome do bucket

### 3.2 Upstash (Redis)

1. **Criar database** em [console.upstash.com](https://console.upstash.com).
   - Type: **Regional** (mais barato no free).
   - Region: **mesma do seu Fly** (ex: `us-west-2` se Fly em `sjc`).
   - TLS: **ON**.
2. **Copiar Redis URL** (formato `rediss://default:<token>@<host>.upstash.io:6379`).
   - ⚠️ **Tem que ser `rediss://`** (com `s` extra = TLS). Não usar `redis://`.

### 3.3 Fly.io (Rails)

```bash
# Login
flyctl auth login

# Criar app (substitua o nome)
flyctl apps create findu-api --org personal
```

Adicionar arquivos no repo do backend (já feito neste projeto):

- `fly.toml` — config do app (2 processos: web + worker, healthcheck, machines)
- `Dockerfile` — production-ready com `tini` (pra Sidekiq drenar jobs no shutdown)
- `.dockerignore` — **CRÍTICO**: impede `.env`, `master.key`, `.git/` de entrar na imagem
- `Gemfile` — precisa de `gem "aws-sdk-s3"` (pro Active Storage com Supabase Storage)
- `Gemfile` — pin `gem "connection_pool", "~> 2.4"` (bug do Sidekiq 7.3 com connection_pool 3.x)

### 3.4 Configurar secrets do Fly

Criar `.env.fly` local (já está no `.gitignore` via padrão `.env.*`):

```bash
chmod 600 .env.fly
```

Conteúdo (substitua os valores):

```bash
# Rails core
RAILS_MASTER_KEY=<conteúdo de config/master.key>
SECRET_KEY_BASE=<openssl rand -hex 64>
DEVISE_JWT_SECRET_KEY=<openssl rand -hex 64>

# Database (Supabase pooler com fallback pra direct connection)
DATABASE_URL=postgresql://postgres:<password>@db.<project-ref>.supabase.co:5432/postgres?sslmode=require

# Redis (Upstash TLS)
REDIS_URL=rediss://default:<token>@<host>.upstash.io:6379

# Supabase Storage (S3-compatível)
SUPABASE_PROJECT_REF=<project-ref>
SUPABASE_BUCKET=findu-storage
SUPABASE_S3_REGION=us-west-2
SUPABASE_S3_ACCESS_KEY_ID=<key>
SUPABASE_S3_SECRET_ACCESS_KEY=<secret>

# CORS / Action Cable
FRONTEND_ORIGIN=https://findu-front-end.vercel.app

# Demais provedores (ajuste conforme suas integrações)
TWILIO_ACCOUNT_SID=<...>
TWILIO_AUTH_TOKEN=<...>
TWILIO_PHONE_NUMBER=<...>
MESSAGING_PROVIDER=twilio
GEMINI_API_KEY=<...>
CHAT_TRANSCRIPTION_PROVIDER=gemini
GEMINI_MODEL_CHAIN=gemini-2.5-flash,gemini-2.5-flash-lite,gemini-2.0-flash
OCR_CONFIDENCE_THRESHOLD=0.7
```

Importar tudo de uma vez:

```bash
flyctl secrets import --app findu-api < .env.fly
flyctl secrets list --app findu-api    # confere
```

### 3.5 Validar DB antes de deployar

```bash
PGPASSWORD=<password> psql "<DATABASE_URL>" -c "SELECT version();"
```

Se não conectar, **não tenta deploy** — o `release_command` vai falhar e abortar tudo.

### 3.6 Deploy do backend

```bash
flyctl deploy --app findu-api
```

O Fly:
1. Builda a imagem Docker.
2. Pusha pro registry.
3. Roda `release_command: bundle exec rails db:migrate` numa máquina efêmera.
4. Sobe `web` + `worker`.
5. Configura DNS `findu-api.fly.dev`.

Validar:

```bash
curl https://findu-api.fly.dev/health    # deve retornar {"status":"ok"}
flyctl status --app findu-api            # 2 machines started (web + worker)
flyctl logs --app findu-api              # tail dos logs
```

### 3.7 Vercel (front-end)

1. Push do repo do front pro GitHub.
2. [vercel.com/new](https://vercel.com/new) → Import repo.
3. Framework Preset: **Next.js** (auto-detect).
4. Environment Variables → adicionar:
   - `NEXT_PUBLIC_API_BASE_URL=https://findu-api.fly.dev/api/v1`
5. Deploy.

Após deploy, pegar a URL (`https://<nome>.vercel.app`) e atualizar no backend:

```bash
flyctl secrets set --app findu-api FRONTEND_ORIGIN="https://<nome>.vercel.app"
```

Isso libera o CORS e o Action Cable `allowed_request_origins`.

### 3.8 Adicionar cartão no Fly (CRÍTICO pra produção)

Sem cartão, o Fly trial **mata máquinas após 5min ociosas**. Worker dorme → chat trava.

Em [fly.io/dashboard/personal/billing](https://fly.io/dashboard/personal/billing) → adicionar método de pagamento.

Não cobra dentro dos limites grátis: 3 VMs `shared-cpu-1x` 256MB. Nossa setup (web + worker + standby) cabe.

---

## 4. Variáveis de ambiente — referência

| Variável | Origem | Onde se usa |
|---|---|---|
| `RAILS_MASTER_KEY` | `config/master.key` local | Descriptografar `credentials.yml.enc` |
| `SECRET_KEY_BASE` | `openssl rand -hex 64` | Cookies/sessions |
| `DEVISE_JWT_SECRET_KEY` | `openssl rand -hex 64` | Assinatura dos JWTs |
| `DATABASE_URL` | Supabase | Conexão Postgres |
| `REDIS_URL` | Upstash | Action Cable + Sidekiq + cache |
| `STORAGE_SERVICE` | Hardcoded no `fly.toml` (`supabase`) | Active Storage backend |
| `SUPABASE_PROJECT_REF` | Supabase URL | Endpoint S3 |
| `SUPABASE_BUCKET` | Você define | Nome do bucket de upload |
| `SUPABASE_S3_REGION` | Supabase | Region do bucket |
| `SUPABASE_S3_ACCESS_KEY_ID` | Supabase Storage → S3 Connection | Auth S3 |
| `SUPABASE_S3_SECRET_ACCESS_KEY` | Supabase Storage → S3 Connection | Auth S3 |
| `FRONTEND_ORIGIN` | URL final da Vercel | CORS + Action Cable allowlist |
| `RAILS_ENV` | `fly.toml` (`production`) | Modo do Rails |
| `RAILS_LOG_TO_STDOUT` | `fly.toml` (`true`) | Logs no `flyctl logs` |
| `RAILS_SERVE_STATIC_FILES` | `fly.toml` (`true`) | API serve estáticos quando necessário |

---

## 5. Operações comuns

```bash
# Alias útil
alias fly=/home/$USER/.fly/bin/flyctl

# ── Deploy ─────────────────────────────────────────
fly deploy --app findu-api

# ── Logs ───────────────────────────────────────────
fly logs --app findu-api                       # todos os processos
fly logs --app findu-api -i <machine-id>       # máquina específica
fly logs --app findu-api --no-tail             # só histórico, sem follow

# ── Status ─────────────────────────────────────────
fly status --app findu-api
fly machines list --app findu-api

# ── SSH na máquina ─────────────────────────────────
fly ssh console --app findu-api                # web
fly ssh console --app findu-api -s worker      # worker

# Rails console em produção (USE COM CUIDADO)
fly ssh console --app findu-api -C "bundle exec rails console"

# ── Secrets ────────────────────────────────────────
fly secrets list --app findu-api                                   # nomes
fly secrets set --app findu-api KEY1=value1 KEY2=value2           # set + restart
fly secrets set --app findu-api --stage KEY=value                  # set sem restart
fly secrets import --app findu-api < .env.fly                     # bulk import

# ── Restart manual ─────────────────────────────────
fly machine restart <machine-id> --app findu-api
fly machine start <machine-id> --app findu-api    # se estiver stopped

# ── Rollback ───────────────────────────────────────
fly releases --app findu-api                       # lista deploys
fly deploy --image registry.fly.io/findu-api:deployment-<id> --app findu-api
```

---

## 6. Troubleshooting (problemas reais que enfrentamos)

### 6.1 `release_command failed: tenant/user postgres.<ref> not found`

**Causa**: URL do pooler Supabase incorreta (region errada ou pooler não habilitado).
**Fix**: usar direct connection como fallback:
```
postgresql://postgres:<pw>@db.<ref>.supabase.co:5432/postgres?sslmode=require
```

### 6.2 `aws-sdk-s3 is not part of the bundle`

**Causa**: Active Storage configurado pra S3 (Supabase Storage usa S3 protocol) mas gem não está no Gemfile.
**Fix**: adicionar `gem "aws-sdk-s3", require: false` ao Gemfile, `bundle install`, redeploy.

### 6.3 Sidekiq scheduler crashou no boot — `ArgumentError: wrong number of arguments`

**Causa**: `connection_pool 3.x` quebra Sidekiq 7.3.x (mudou assinatura de `pop`).
**Fix**: pinar `gem "connection_pool", "~> 2.4"` no Gemfile.

### 6.4 Action Cable rejeita WebSocket — `Request origin not allowed`

**Causa**: o `rack-cors` NÃO se aplica ao Action Cable. Action Cable tem sua própria allowlist.
**Fix**: em `config/environments/production.rb`:
```ruby
config.action_cable.allowed_request_origins = [
  ENV.fetch("FRONTEND_ORIGIN", ""),
  %r{\Ahttps://[a-z0-9\-]+\.vercel\.app\z}
]
```

### 6.5 Worker dorme após 5min — "Trial machine stopping"

**Causa**: trial do Fly sem cartão. Mata máquinas ociosas.
**Fix**: adicionar método de pagamento em [fly.io/dashboard/personal/billing](https://fly.io/dashboard/personal/billing). Não cobra no free.

### 6.6 Gemini retorna "high demand" pra qualquer modelo

**Causa**: nome de modelo inválido (Gemini retorna esse erro genérico em vez de "model not found").
**Fix**: verificar nomes válidos em [ai.google.dev/models](https://ai.google.dev/models). Em 2026, modelos válidos comuns: `gemini-2.5-flash`, `gemini-2.5-flash-lite`, `gemini-2.0-flash`, `gemini-2.5-pro`.

### 6.7 `Your Redis network connection is performing extremely poorly. RTT 60000ms+`

**Causa**: Redis Upstash em region distante do Fly, OU Sidekiq saturado.
**Fix**: criar Redis novo no Upstash na mesma region do Fly, atualizar `REDIS_URL`.

### 6.8 Vercel preview de PR não funciona com o backend

**Causa**: CORS bloqueia origens dinâmicas tipo `findu-git-feature-x.vercel.app`.
**Fix**: o `cors.rb` deste projeto já permite via regex `*.vercel.app` por padrão.

---

## 7. Custos esperados (Stack 2)

| Serviço | Free tier | Quando paga |
|---|---|---|
| **Fly.io** | 3 VMs `shared-cpu-1x` 256MB + 3GB storage | Acima disso ou bandwidth alto |
| **Supabase** | 500MB DB, 1GB storage, projeto **pausa após 7 dias sem uso** | $25/mês Pro pra não pausar |
| **Upstash** | 10k comandos/dia, 256MB | Acima — Plano "Pay as you go" |
| **Vercel** | 100GB bandwidth/mês, builds ilimitados | Acima — Pro $20/mês |

**Total esperado MVP baixo tráfego: $0/mês** (com cartão registrado no Fly por exigência).

---

## 8. Hardening pendente

Quando o MVP virar produção real:

- [ ] `config.force_ssl = true` em `production.rb`
- [ ] Trocar `DATABASE_URL` direct connection pelo pooler (limite 60 conexões)
- [ ] Restringir `allowed_request_origins` ao domínio Vercel exato (sem regex amplo)
- [ ] Mover Redis Upstash pra mesma region do Fly (resolver RTT alto)
- [ ] UptimeRobot pingando `/health` a cada 5min (evita Supabase pausar após 7 dias)
- [ ] Rotacionar secrets que foram expostos durante o setup
- [ ] Configurar Sentry/Honeybadger pra error tracking
- [ ] Plano Pro Supabase ($25/mês) pra não ter pause
- [ ] Backup automático do DB (Supabase Pro tem PITR)

---

## 9. Como replicar essa stack para uma nova aplicação

```bash
# 1. Cria as contas (Fly, Supabase, Upstash, Vercel)
# 2. Cria o app
flyctl apps create <nome>-api --org personal

# 3. Copia 4 arquivos deste projeto pro novo (ajustando):
cp .dockerignore /caminho/novo-projeto/
cp Dockerfile    /caminho/novo-projeto/
cp fly.toml      /caminho/novo-projeto/    # ajustar app name + primary_region

# 4. Garantir gems no Gemfile:
#    gem "aws-sdk-s3", require: false
#    gem "connection_pool", "~> 2.4"
#    gem "rack-cors"

# 5. Copiar config/initializers/cors.rb (allowlist Vercel)

# 6. Em production.rb, adicionar action_cable.allowed_request_origins

# 7. Criar .env.fly com os 19 secrets

# 8. flyctl secrets import --app <nome>-api < .env.fly

# 9. flyctl deploy --app <nome>-api

# 10. Vercel: importa o front, adiciona NEXT_PUBLIC_API_BASE_URL

# 11. flyctl secrets set FRONTEND_ORIGIN="https://<url>.vercel.app"

# 12. flyctl deploy (rolling restart aplica)
```

Veja também [`CICD.md`](./CICD.md) pra automação via GitHub Actions e [`AWS-MIGRATION.md`](./AWS-MIGRATION.md) pra migração futura.
