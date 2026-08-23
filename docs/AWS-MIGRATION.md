# Migração para AWS — Tutorial pragmático

Quando sair do free tier (Fly + Supabase + Upstash + Vercel) e precisar de uma infra "de adulto" na AWS, este é o caminho mais sensato e barato pra um app Rails + Sidekiq + Postgres + Redis + Next.js.

**Não tente recriar tudo manualmente na primeira vez.** Use serviços managed e ferramentas que cuidam de boilerplate.

---

## 1. Mapeamento serviço-a-serviço

| Hoje (Stack 2) | AWS equivalente | Justificativa |
|---|---|---|
| **Fly.io** (web + worker) | **AWS App Runner** (web) + **ECS Fargate** (worker) | App Runner = experiência Fly-like; Sidekiq precisa de container persistente |
| **Supabase Postgres** | **RDS Postgres** (com Multi-AZ em produção) | Padrão da indústria |
| **Upstash Redis** | **ElastiCache for Redis** (Serverless) | Managed, fácil |
| **Supabase Storage** | **S3** + signed URLs | S3 é nativo, mais barato |
| **Vercel (Next.js)** | **AWS Amplify Hosting** (preferido) ou **CloudFront + S3** | Amplify imita Vercel; CloudFront+S3 é mais barato em escala |
| **DNS** | **Route 53** | Integra com tudo |
| **TLS certs** | **ACM (Certificate Manager)** | Gratuito |
| **Logs** | **CloudWatch Logs** | Padrão |
| **Secrets** | **Secrets Manager** ou **SSM Parameter Store** | SSM mais barato; Secrets Manager rotaciona |
| **Deploy CI/CD** | GitHub Actions com OIDC (sem secret no GH) | Padrão moderno |
| **Container registry** | **ECR** | Necessário pra App Runner / Fargate |

---

## 2. Topologia recomendada (custo otimizado)

```
                       Route 53 (DNS)
                            │
              ┌─────────────┴──────────────┐
              ▼                            ▼
    ┌──────────────────┐         ┌──────────────────┐
    │ Amplify Hosting  │         │   App Runner     │
    │ (Next.js front)  │         │   (Rails web)    │
    └──────────────────┘         └────────┬─────────┘
                                          │
                       ┌──────────────────┼──────────────────┐
                       │                  │                  │
                       ▼                  ▼                  ▼
              ┌──────────────┐   ┌────────────────┐  ┌─────────────┐
              │ ECS Fargate  │   │ RDS Postgres   │  │ ElastiCache │
              │ (Sidekiq)    │   │  db.t4g.micro  │  │ Redis Serv. │
              └──────┬───────┘   └────────────────┘  └─────────────┘
                     │
                     └─► S3 (Active Storage)
```

**Por que separar web e worker?**
- App Runner é mais simples e tem auto-scaling, MAS não suporta workers permanentes (precisa receber HTTP).
- Sidekiq é background, então precisa rodar em ECS Fargate como service "always-on".

**Alternativa mais barata, mais trabalhosa**: rodar tudo em 1 instância EC2 t4g.small (~$13/mês) com Docker Compose. Vira "infra escola" e te ensina muito, mas não escala.

---

## 3. Setup (ordem recomendada)

### 3.1 Conta + organização

1. Criar conta AWS root.
2. **NÃO use a root user pra nada** — só pra criar uma OU/Account de billing e o admin IAM.
3. Habilitar **MFA** no root e no IAM admin.
4. Habilitar **AWS Cost Anomaly Detection** + alerta de orçamento.
5. Setar region default: `us-west-2` (Oregon) se seu público é US/global; `sa-east-1` (São Paulo) se BR.

### 3.2 IAM — usuário pessoal de admin

```
IAM → Users → Create user
  Name: erural
  Access type: console
  Permissions: attach policy "AdministratorAccess"
  Enable MFA
```

Crie **um access key separado** com escopo restrito pra CLI:

```bash
aws configure
# AWS Access Key ID: ...
# AWS Secret Access Key: ...
# Default region: us-west-2
```

### 3.3 VPC

A AWS já cria uma **default VPC** em cada region. Use ela no início. Quando o projeto crescer, crie VPCs próprias com Terraform.

### 3.4 ECR — Container Registry

```bash
# Cria o repositório
aws ecr create-repository --repository-name findu-api --region us-west-2

# Login no Docker
aws ecr get-login-password --region us-west-2 | docker login \
  --username AWS \
  --password-stdin <ACCOUNT_ID>.dkr.ecr.us-west-2.amazonaws.com

# Build e push
docker build -t findu-api .
docker tag findu-api:latest <ACCOUNT_ID>.dkr.ecr.us-west-2.amazonaws.com/findu-api:latest
docker push <ACCOUNT_ID>.dkr.ecr.us-west-2.amazonaws.com/findu-api:latest
```

### 3.5 RDS — PostgreSQL

```
RDS → Create database
  Engine: PostgreSQL 17
  Template: Free tier (ou Production p/ Multi-AZ)
  Instance: db.t4g.micro    # menor possível
  Storage: 20 GB gp3
  Multi-AZ: Off (free) / On (produção)
  VPC: default
  Public access: No
  Initial DB name: findu_production
  Master username: findu_admin
  Master password: <gere via Secrets Manager>
```

Anota o endpoint: `findu-db.xxxxx.us-west-2.rds.amazonaws.com`.

**Conexão URL**:
```
postgresql://findu_admin:<password>@findu-db.xxx.us-west-2.rds.amazonaws.com:5432/findu_production?sslmode=require
```

Free tier: 750h/mês de `db.t2.micro` ou `db.t3.micro` por 12 meses.

### 3.6 ElastiCache — Redis Serverless

```
ElastiCache → Create serverless cache
  Cache name: findu-redis
  Engine: Redis 7 (com TLS)
  VPC: default
  Min/Max capacity: deixa default
```

Anota o endpoint. Use TLS (porta 6380).

**REDIS_URL** vai virar: `rediss://findu-redis.xxx.cache.amazonaws.com:6380`

**ElastiCache Serverless cobra ~$0.125/hora mesmo ocioso** (~$90/mês). Pra MVP, considere uma instância EC2 + Docker Redis (~$5/mês) ou continuar no Upstash.

### 3.7 S3 — Storage

```bash
aws s3 mb s3://findu-storage-prod --region us-west-2
aws s3api put-public-access-block \
  --bucket findu-storage-prod \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

Criar IAM user pra Active Storage (mais seguro que usar a sua key pessoal):

```
IAM → Users → Create user "findu-storage-app"
  Programmatic access
  Inline policy:
    {
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"],
        "Resource": [
          "arn:aws:s3:::findu-storage-prod",
          "arn:aws:s3:::findu-storage-prod/*"
        ]
      }]
    }
```

No `config/storage.yml` adicionar:

```yaml
amazon:
  service: S3
  access_key_id: <%= ENV["AWS_ACCESS_KEY_ID"] %>
  secret_access_key: <%= ENV["AWS_SECRET_ACCESS_KEY"] %>
  region: <%= ENV.fetch("AWS_REGION", "us-west-2") %>
  bucket: <%= ENV["AWS_S3_BUCKET"] %>
```

Setar `STORAGE_SERVICE=amazon`.

### 3.8 Secrets Manager (ou SSM Parameter Store)

Pra cada secret do `.env.fly`, criar uma entrada:

```bash
aws secretsmanager create-secret --name findu/production/RAILS_MASTER_KEY \
  --secret-string "<value>"
```

Ou em batch via JSON. SSM Parameter Store é ~10x mais barato pra secrets simples.

### 3.9 App Runner — Rails web

```
App Runner → Create service
  Source: ECR Image
  Image: <ACCOUNT_ID>.dkr.ecr.us-west-2.amazonaws.com/findu-api:latest
  Deployment trigger: Automatic (em cada push na tag :latest)
  Service name: findu-api-web
  Port: 8080
  Health check: HTTP /health
  CPU: 0.25 vCPU
  Memory: 0.5 GB
  Auto scaling: 1 a 5 instances
  Environment variables: importar do Secrets Manager
  VPC connector: criar pra acessar RDS + ElastiCache (na mesma VPC)
```

App Runner faz HTTPS automático + domain `findu-api.xxxxx.awsapprunner.com`.

**Custo**: ~$0.064/vCPU-hora + ~$0.007/GB-hora. Com 0.25 vCPU + 0.5GB rodando 24/7: ~$15/mês.

### 3.10 ECS Fargate — Sidekiq worker

App Runner não serve aqui (não tem HTTP). Use ECS Fargate.

Recomendação: usa **AWS Copilot** pra evitar montar Task Definition, Service, IAM role na mão.

```bash
# Instala Copilot
curl -Lo copilot https://github.com/aws/copilot-cli/releases/latest/download/copilot-linux
chmod +x copilot && sudo mv copilot /usr/local/bin/

# Inicializa
cd /caminho/findu
copilot init
  Application: findu
  Workload: Worker Service
  Name: worker
  Dockerfile: ./Dockerfile
  Command: bundle exec sidekiq

copilot deploy
```

Copilot cuida de ECS cluster, Task Definition, IAM, log group, etc.

**Custo**: 0.25 vCPU + 0.5 GB 24/7 = ~$8/mês.

### 3.11 Amplify Hosting — Next.js front

```
Amplify → Create new app → Host web app
  Source: GitHub → Ca788/findu-front-end
  Branch: main
  Build settings: auto-detect Next.js (gera amplify.yml)
  Environment variables:
    NEXT_PUBLIC_API_BASE_URL: https://api.findu.app/api/v1
```

Amplify faz preview por branch (similar a Vercel) e suporta server-side rendering Next.js completo desde 2024.

**Custo**: $0.01/build-min + $0.15/GB servido. Pra MVP: ~$1-5/mês.

### 3.12 Route 53 + ACM — domínio próprio

```
Route 53 → Create hosted zone
  Domain: findu.app  (compra na Route 53 ou outro registrar)

ACM → Request certificate
  Domain: api.findu.app, *.findu.app
  Validation: DNS (auto-validado se está na Route 53)

Route 53 → Records:
  A    findu.app          → Amplify
  A    api.findu.app      → App Runner Custom Domain
```

---

## 4. CI/CD na AWS (substituir GitHub Actions → Fly por GitHub Actions → AWS)

Recomendação: **OIDC** (sem secrets de AWS no GitHub).

### 4.1 Criar OIDC provider

```
IAM → Identity providers → Add provider
  Type: OpenID Connect
  Provider URL: https://token.actions.githubusercontent.com
  Audience: sts.amazonaws.com
```

### 4.2 Criar IAM Role assumível pelo GitHub

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:Ca788/findu:ref:refs/heads/main"
      }
    }
  }]
}
```

Permissions: `AmazonEC2ContainerRegistryPowerUser` + `AWSAppRunnerFullAccess`.

### 4.3 Workflow GitHub Actions

```yaml
name: Deploy to AWS

on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::<ACCOUNT_ID>:role/GitHubDeployRole
          aws-region: us-west-2

      - name: Login ECR
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build and push
        run: |
          docker build -t findu-api .
          IMAGE=<ACCOUNT_ID>.dkr.ecr.us-west-2.amazonaws.com/findu-api
          docker tag findu-api:latest $IMAGE:${{ github.sha }}
          docker tag findu-api:latest $IMAGE:latest
          docker push $IMAGE:${{ github.sha }}
          docker push $IMAGE:latest

      - name: Deploy App Runner (web)
        run: |
          aws apprunner start-deployment --service-arn <APPRUNNER_ARN>

      - name: Deploy Copilot (worker)
        run: |
          copilot deploy --name worker --env production
```

---

## 5. Custos esperados (Stack AWS, MVP baixo tráfego)

| Serviço | Custo/mês |
|---|---|
| RDS db.t4g.micro (sem Multi-AZ) | ~$13 (grátis 12 meses) |
| ElastiCache Serverless | ~$90 (caro — considere EC2+Docker) |
| App Runner (0.25 vCPU/0.5GB) | ~$15 |
| ECS Fargate worker | ~$8 |
| S3 (10GB + tráfego baixo) | <$1 |
| Route 53 (hosted zone) | $0.50 |
| Amplify Hosting | ~$1-5 |
| Data Transfer | varia |
| **Total** | **~$130/mês** |

**Comparativo Stack 2 (Fly+Supabase+Upstash+Vercel)**: $0/mês free, ~$50/mês quando sair do free.

**Conclusão**: AWS só vale se você precisa de Multi-AZ, compliance específica (HIPAA, PCI), integração com outros serviços AWS (SES, Lambda, etc), ou já tem desconto enterprise.

---

## 6. Alternativas de migração mais baratas

| Cenário | Recomendação |
|---|---|
| **MVP até $500/mês** | Continue na Stack 2 + cartão Fly + Supabase Pro |
| **MVP até $2k/mês com Multi-AZ** | DigitalOcean App Platform + Managed DB + Managed Redis (~$60/mês) |
| **Precisa AWS por requisito** | Stack AWS acima (com EC2+Redis em vez de ElastiCache) |
| **Sair completamente de PaaS** | Terraform + EC2 + Docker Swarm / k3s |

---

## 7. Checklist antes de migrar pra AWS

- [ ] App roda em produção sem incidentes há pelo menos 30 dias
- [ ] Backup automático configurado e **testado** (restore real)
- [ ] Logs estruturados (JSON) e tracking de erros (Sentry)
- [ ] Métricas básicas (latência p50/p95/p99, error rate)
- [ ] Documentação de operações (este doc + runbooks)
- [ ] CI/CD que faz rollback automático em falha
- [ ] Orçamento mensal aprovado com 30% de buffer pra surpresas
- [ ] **Não migra tudo de uma vez** — móve um serviço por vez (ex: primeiro DB, depois worker, depois web)

---

## 8. Erros comuns a evitar na AWS

1. **Deixar S3 público sem querer** → vaza dados. Use Block Public Access em todos os buckets.
2. **Rodar workloads em região cara sem necessidade**. `us-east-1` é mais barata que `sa-east-1` (~30% diff).
3. **Não setar billing alerts**. Configure alarme em $50, $100, $500.
4. **Usar root user pra qualquer coisa além de criar o IAM admin**.
5. **Salvar AWS access keys no GitHub**. Use OIDC sempre.
6. **Multi-AZ no MVP**: dobra o custo do RDS sem necessidade real até ter usuários reais 24/7.
7. **NAT Gateway pra VPC privada no MVP**: cobra $32/mês por AZ + tráfego. Use VPC default e ponha o app em subnet pública com Security Group bem fechado.
8. **Backup só por snapshot**. Configure PITR (Point-In-Time Recovery) no RDS.

---

## 9. Recursos pra aprofundar

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/) — checklist oficial
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials) — OIDC
- [AWS Copilot](https://aws.github.io/copilot-cli/) — abstração de ECS pra desenvolvedor
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest) — IaC quando passar da fase de PaaS
- [aws-pricing-calculator](https://calculator.aws/) — estima custos antes de criar

---

## 10. Quando NÃO migrar pra AWS

- Time pequeno (<5 engenheiros): PaaS (Fly, Railway, Render) entrega mais valor.
- App single-tenant: a complexidade de AWS é injustificada.
- Você não tem **orçamento dedicado** pra um DevOps em call quando algo quebrar às 2h da manhã.

**Regra de ouro**: se você não consegue listar 3 razões concretas pra migrar, não migra.
