# WCore - Motor de Estado em Tempo Real (BEAM/Elixir + Phoenix LiveView)

Motor de estado mission-critical para plantas industriais: recebe heartbeats de milhares de sensores com baixa latência, atualiza o dashboard em tempo real via ETS/OTP e persiste de forma eventual em SQLite (write-behind + upsert).

**Recursos:** ingestão fire-and-forget; ETS quente com `:set` e atualização por `:ets.update_counter/4`; write-behind assíncrono com `Repo.insert_all/3`; upsert via `unique_index`; dashboard LiveView com PubSub incremental; autenticação gerada por `phx.gen.auth`; Docker multi-stage + Elixir release.

---

## Arquitetura do sistema

```mermaid
graph TB
    S[Sensor - Edge Device] -->|heartbeat JSON| E[HTTP Endpoint - POST api telemetry ingest]
    E -->|cast rápido| I[GenServer - WCore.Telemetry.Ingestor]
    I --> ETS[ETS w_core_telemetry_cache]
    ETS -->|flush em lote| W[Worker assíncrono - WCore.Telemetry.WriteBehindWorker]
    W -->|upsert| DB[SQLite - w_core.db VOLUME]

    I -->|node_status (node_id, status)| PubSub[Phoenix.PubSub]
    PubSub --> LV[LiveView Dashboard - WCoreWeb.DashboardLive]
    LV --> R[Render incremental do card por máquina]
```

---

## Estrutura do projeto

```
./
├── Dockerfile
├── rel/
│   └── env.sh.eex
├── drafts/
│   ├── step-1-foundation.md
│   ├── step-2-otp-ets.md
│   ├── step-3-liveview-ds.md
│   ├── step-4-tests.md
│   └── step-5-infra-arch.md
├── lib/
│   ├── w_core/
│   │   ├── application.ex
│   │   └── telemetry/
│   │       ├── ingestor.ex
│   │       └── write_behind_worker.ex
│   └── w_core_web/
│       ├── controllers/
│       │   └── telemetry_ingest_controller.ex
│       ├── live/
│       │   └── dashboard_live.ex
│       └── components/
│           └── industrial_components.ex
└── priv/
    └── repo/
        └── migrations/
```

---

## Endpoints

| Método | Rota | Quem usa | Auth |
|-------|------|-----------|------|
| `POST` | `/api/telemetry/ingest` | Sensor/Edge Device | não (ingestão) |
| `GET` | `/dashboard` | Operador da planta | sim (sessão gerada em `phx.gen.auth`) |

---

## Como enviar um heartbeat (simulação de sensor)

Antes de enviar telemetria, o `node_id` precisa existir em `nodes` (tabela de sensores/máquinas).

Exemplo (payload mínimo):

```bash
curl -X POST "http://localhost:4000/api/telemetry/ingest" \
  -H "content-type: application/json" \
  -d '{
    "node_id": 1,
    "status": "ok",
    "payload": {},
    "timestamp": "2026-03-25T14:00:00Z"
  }'
```

Observações:
- `timestamp` é opcional; se vier, o sistema normaliza para `:utc_datetime` sem microsegundos.
- a ingestão é fire-and-forget (resposta `202 Accepted`), e a persistência no SQLite ocorre em lote.

---

## O que cada módulo faz

### `lib/w_core/application.ex`
Cria a ETS no boot (`:w_core_telemetry_cache`) e registra os processos do pipeline:
- `WCore.Telemetry.Ingestor`
- `WCore.Telemetry.WriteBehindWorker`

### `lib/w_core/telemetry/ingestor.ex`
Hot-path de ingestão:
- valida o formato do evento
- atualiza o contador em ETS com `:ets.update_counter/4`
- atualiza campos quentes (status + último payload) com `:ets.insert/2`
- publica apenas `{:node_status, node_id, status}` no PubSub

### `lib/w_core/telemetry/write_behind_worker.ex`
Persistência eventual:
- a cada ~5s, faz `:ets.tab2list/1`
- projeta em linhas compatíveis com `node_metrics`
- faz upsert em lote com `Repo.insert_all/3` usando `conflict_target: [:node_id]`

### `lib/w_core_web/controllers/telemetry_ingest_controller.ex`
Endpoint HTTP para simular sensores enviando JSON.
Converte payload/`timestamp` para `DateTime` e chama `WCore.Telemetry.Ingestor.ingest/1`.

### `lib/w_core_web/live/dashboard_live.ex` + `industrial_components.ex`
Dashboard em tempo real:
- `mount/3` carrega snapshot inicial da ETS
- `handle_info/2` reage ao PubSub e atualiza apenas o card da máquina afetada
- componentes HEEx mantêm o design sem dependências pesadas

---

## Como rodar (dev)

```bash
source ~/.asdf/asdf.sh
mix deps.get
mix ecto.migrate
mix phx.server
```

Acesse:
- `http://localhost:4000/dashboard` (login primeiro)

---

## Como rodar com Docker (release)

### Pré-requisitos

- Docker + Docker Compose instalados (`docker` e `docker compose`)
- Porta `4000` livre (ou ajuste o mapeamento no compose)

### 1) Subir o projeto

Na raiz do projeto:

```bash
docker compose up --build
```

O container sobe o release e já roda as migrations automaticamente (se necessário). O SQLite fica persistido no volume do Docker (`/data/w_core.db`).

### 2) Abrir as páginas (registro / login / dashboard)

Com o container rodando, abra:

- Registro: `http://localhost:4000/users/register`
- Login: `http://localhost:4000/users/log-in`
- Dashboard (requer login): `http://localhost:4000/dashboard`

Fluxo esperado:
- Se você acessar `/dashboard` sem estar autenticado, você será redirecionado para `/users/log-in`.

### 3) Criar um usuário (registro)

1. Acesse `http://localhost:4000/users/register`
2. Preencha **Email** e **Password**
3. Envie o formulário

Depois disso, você consegue fazer login normalmente.

### 4) Fazer login

1. Acesse `http://localhost:4000/users/log-in`
2. Use o mesmo **Email** e **Password** do registro
3. Envie o formulário

Você será redirecionado e conseguirá acessar o dashboard.

### 5) Teste rápido de rotas (smoke test)

Este projeto inclui um script que:
- builda a imagem
- sobe um container numa **porta livre** automaticamente
- valida `GET /users/log-in`, `GET /users/register`
- valida que `GET /dashboard` (sem login) redireciona para `/users/log-in`

```bash
./scripts/docker_smoke_test.sh
```

Observação importante:
- Se você estiver com `docker compose up` rodando na porta `4000`, o smoke test **não conflita**, porque ele escolhe uma porta aleatória livre.

### 6) Configuração de `SECRET_KEY_BASE` (produção)

O `SECRET_KEY_BASE` precisa ter **pelo menos 64 bytes**, senão o Plug/Phoenix retorna erro ao tentar usar sessão/cookies.

No `docker-compose.yml` já existe um fallback seguro, mas para algo mais “prod”, você pode setar via variável:

```bash
export SECRET_KEY_BASE="$(python3 -c 'import secrets; print(secrets.token_urlsafe(64))')"
docker compose up --build
```

---

## Deploy no Edge (release + Docker)

No runtime do container:
- `DATABASE_PATH=/data/w_core.db` aponta para um arquivo em `VOLUME` (preserva histórico)
- o release roda com `PHX_SERVER=true`

Arquivos relevantes:
- `Dockerfile`
- `rel/env.sh.eex`

