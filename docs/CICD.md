# CI/CD — GitHub Actions

Documenta a automação de testes e deploy contínuo dos dois repos:

| Repo | Workflow | Trigger | Função |
|---|---|---|---|
| `Ca788/findu` (backend) | `.github/workflows/ci.yml` | PR + push em `main` | Roda RSpec |
| `Ca788/findu` (backend) | `.github/workflows/deploy.yml` | Push em `main` | Deploy automático no Fly.io |
| `Ca788/findu-front-end` | `.github/workflows/ci.yml` | PR + push em `main` | Lint + typecheck + build |
| `Ca788/findu-front-end` | — | Push em `main` | Vercel deploy automático (via GitHub App) |

> ⚠️ **Frontend não tem workflow de deploy.** A Vercel já tem integração nativa com GitHub que faz deploy a cada push em `main` e preview em cada PR. Não precisa configurar Action.

---

## 1. Fluxo de cada ambiente

```
                    ┌────────────────────────┐
                    │ Pull Request (qualquer)│
                    └───────────┬────────────┘
                                │
                  ┌─────────────┴──────────────┐
                  ▼                            ▼
         ┌────────────────┐         ┌─────────────────────┐
         │ Backend CI     │         │ Frontend CI         │
         │ (RSpec)        │         │ (lint/tsc/build)    │
         └────────┬───────┘         └──────────┬──────────┘
                  │                            │
                  │                            ▼
                  │                  ┌────────────────────┐
                  │                  │ Vercel Preview     │
                  │                  │ (URL única por PR) │
                  │                  └────────────────────┘
                  │
                  └─► Merge na main (requer reviewers + checks verdes)
                            │
              ┌─────────────┴──────────────┐
              ▼                            ▼
     ┌────────────────┐         ┌──────────────────────┐
     │ Backend Deploy │         │ Vercel Production    │
     │ (Fly.io)       │         │ (automático)         │
     └────────────────┘         └──────────────────────┘
```

---

## 2. Setup inicial (precisa fazer uma vez por repo)

### 2.1 Backend (`Ca788/findu`) — Secret `FLY_API_TOKEN`

```bash
# Gerar um token específico pra esse app (não usar o token pessoal)
flyctl tokens create deploy --app findu-api --expiry 8760h

# Saída: copia o token completo (começa com FlyV1 ...)
```

No GitHub:
1. Vai em `https://github.com/Ca788/findu/settings/secrets/actions`
2. **New repository secret**
3. Name: `FLY_API_TOKEN`
4. Secret: cola o token

### 2.2 Backend — Secret `RAILS_MASTER_KEY` (pro CI rodar testes)

```bash
cat config/master.key
```

GitHub → Settings → Secrets → New:
- Name: `RAILS_MASTER_KEY`
- Secret: o valor exato do `master.key`

### 2.3 Frontend (`Ca788/findu-front-end`) — Conectar Vercel ao GitHub

Já está feito quando você importou o repo na Vercel. Confirmar em:
`https://vercel.com/<seu-time>/findu-front-end/settings/git`

- Production Branch: `main`
- Auto-deploy: ON

A Vercel cria automaticamente:
- Deploy em `https://findu-front-end.vercel.app` a cada push em `main`.
- Preview em `https://findu-front-end-git-<branch>-<team>.vercel.app` pra cada PR.

> O regex no `cors.rb` do backend (`%r{\Ahttps://[a-z0-9\-]+\.vercel\.app\z}`) já libera as URLs de preview automaticamente.

### 2.4 Configurar branch protection (recomendado)

No GitHub, pra cada repo:

`Settings → Branches → Branch protection rules → Add rule`:
- Branch name pattern: `main`
- **Require a pull request before merging** ✅
  - Required approvals: 1 (ou mais)
- **Require status checks to pass before merging** ✅
  - Search: `RSpec` (backend), `Lint + Typecheck + Build` (front), `Vercel`
- **Require branches to be up to date before merging** ✅
- **Do not allow bypassing the above settings** ✅

---

## 3. Workflows detalhados

### 3.1 Backend — `ci.yml` (testes)

Roda em PRs e em pushes em `main`.

Faz:
1. Sobe Postgres 17 e Redis 7 como services.
2. Setup Ruby (versão lida do `.ruby-version` ou `Gemfile`).
3. `bundle install` (com cache de gems).
4. `rails db:test:prepare`.
5. `rspec --format documentation`.

Falha se qualquer teste quebrar → bloqueia merge.

### 3.2 Backend — `deploy.yml` (deploy)

Roda só em pushes na `main` (ou manualmente via "Run workflow").

Faz:
1. Setup `flyctl`.
2. `flyctl deploy --remote-only --app findu-api` — usa o builder do Fly (não builda local).
3. Healthcheck: 5 tentativas de `curl /health` com 10s de espera.

Se o deploy falhar OU o healthcheck falhar → o Action falha e o GitHub avisa.

> `concurrency: cancel-in-progress: false` garante que dois deploys nunca rodem simultaneamente (evita race entre `release_command` e rolling deploy).

### 3.3 Frontend — `ci.yml` (validação)

Roda em PRs e pushes em `main`.

Faz:
1. Setup Node 20 + Corepack (pro Yarn 4 do `packageManager`).
2. `yarn install --immutable`.
3. `yarn lint`.
4. `yarn tsc --noEmit` (typecheck sem emitir arquivos).
5. `yarn build` com `NEXT_PUBLIC_API_BASE_URL` apontando pra produção.

---

## 4. Como atualizar secrets de produção sem precisar de outro deploy

Secret só de runtime (não muda código):

```bash
flyctl secrets set --app findu-api MINHA_CHAVE="novo-valor"
```

→ Fly faz rolling restart das máquinas automaticamente. Sem precisar de novo deploy GitHub.

Pra setar vários sem restart (e depois fazer restart de uma vez):

```bash
flyctl secrets set --stage --app findu-api KEY1=v1 KEY2=v2
flyctl deploy --app findu-api    # aplica todos juntos
```

---

## 5. Como fazer rollback rápido

### Backend

```bash
# Listar releases
flyctl releases --app findu-api

# Voltar pra release anterior
flyctl deploy --image registry.fly.io/findu-api:deployment-<id-antigo> --app findu-api
```

### Frontend (Vercel)

1. [vercel.com/<time>/findu-front-end/deployments](https://vercel.com)
2. Clica nos `...` da deployment anterior estável.
3. **Promote to Production**.

---

## 6. Como adicionar um ambiente de staging (futuro)

Padrão recomendado:

1. Branch protegida `staging` no GitHub.
2. App separado no Fly: `flyctl apps create findu-api-staging --org personal`.
3. Banco separado (Supabase Free permite múltiplos projetos).
4. Workflow novo `.github/workflows/deploy-staging.yml`:
   ```yaml
   on:
     push:
       branches: [staging]
   ```
5. Frontend: a Vercel já cria preview deploys automaticamente por branch — não precisa de Action separado, basta configurar um domínio dedicado (ex: `staging.findu.app`).

---

## 7. Custos do CI/CD

| Item | Free tier |
|---|---|
| **GitHub Actions** | 2000 min/mês em repos privados (grátis ilimitado em públicos) |
| **Fly.io builds** | Remote builder grátis no Fly |
| **Vercel builds** | 100 builds/dia no Hobby plan |

Pra MVP, tudo dentro do free.

---

## 8. Boas práticas (devops sênior)

- **Nunca commitar secrets**. Use GitHub Secrets + `flyctl secrets`.
- **Não usar `latest` no Dockerfile** — pin de versão (`ruby:3.3.5-slim`).
- **Branch protection ON** desde o dia 1.
- **Health check obrigatório no deploy** (já está no `deploy.yml`).
- **Concurrency lock no deploy** (evita race conditions).
- **Rollback testado pelo menos 1x** antes de precisar em emergência.
- **Logs centralizados**: integrar com Better Stack, Logtail ou Datadog quando o tráfego crescer.
- **Error tracking**: Sentry/Honeybadger desde o início (free tier basta no MVP).
