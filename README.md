# Findu API

API de um assistente financeiro pessoal: ingere dados crus (recibos, mensagens de WhatsApp, áudios e textos via chat) e os transforma em **transações financeiras estruturadas**, com suporte a categorias, orçamentos por período, parcelamentos e respostas inteligentes via LLM.

> Construída em Rails 7 (API-only), PostgreSQL, Redis, Sidekiq e Active Storage. Arquitetura DDD com `domain/use_case` + `infrastructure`.

---

## Sumário

- [Stack](#stack)
- [Arquitetura](#arquitetura)

---

## Stack

- **Ruby** 3.3.5
- **Rails** 7.0 (API-only)
- **PostgreSQL** 16 (UUID como PK padrão)
- **Redis** 7
- **Sidekiq** 7 (Active Job adapter)
- **Active Storage** (anexos de áudio/imagem)
- **Devise + Devise-JWT** (autenticação)
- **Blueprinter** (serialização)
- **Kaminari** (paginação)
- **RSpec + FactoryBot + Faker** (testes)
- **RubyLLM + ruby_llm-schema** (chamadas LLM com saída estruturada)
- **Twilio** (mensageria — WhatsApp)
- **Google Gemini** (classificação de intenção, extração de transações, OCR de recibos, transcrição de áudio)

## Arquitetura

DDD com camadas explícitas:

```
app/
├── controllers/         → HTTP boundary (api/v1/*)
├── domain/use_case/     → orquestração de regras de negócio
├── models/              → Active Record (entidades)
├── infrastructure/      → integrações externas (LLM, OCR, mensageria, formatadores)
├── serializers/         → Blueprinter (V1::*)
└── jobs/                → Sidekiq workers
```
