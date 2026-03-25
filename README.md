# WCore - Motor de Estado em Tempo Real (BEAM/Elixir + Phoenix LiveView)

Motor de estado mission-critical para plantas industriais: recebe heartbeats de milhares de sensores com baixa latência, atualiza o dashboard em tempo real via ETS/OTP e persiste de forma eventual em SQLite (write-behind + upsert).

**Recursos:** ingestão fire-and-forget; ETS quente com `:set` e atualização por `:ets.update_counter/4`; write-behind assíncrono com `Repo.insert_all/3`; upsert via `unique_index`; dashboard LiveView com PubSub incremental; autenticação gerada por `phx.gen.auth`; Docker multi-stage + Elixir release.

---

## Arquitetura do sistema

```mermaid
graph TB
    S[Sensor / Edge Device] -->|heartbeat JSON| E[HTTP Endpoint<br/>POST /api/telemetry/ingest]
    E -->|cast rápido| I[GenServer<br/>WCore.Telemetry.Ingestor]
    I --> ETS[(ETS: :w_core_telemetry_cache)]
    ETS -->|flush em lote| W[Worker assíncrono<br/>WCore.Telemetry.WriteBehindWorker]
    W -->|upsert| DB[SQLite<br/>w_core.db (VOLUME)]

    I -->|{:node_status, node_id, status}| PubSub[Phoenix.PubSub]
    PubSub --> LV[LiveView Dashboard<br/>WCoreWeb.DashboardLive]
    LV --> R[Render incremental do card por máquina]
```

---

## Estrutura do projeto

```
w_core/
├── Dockerfile
├── rel/
│   └── env.sh.eex
├── docs/drafts/
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
cd w_core
mix deps.get
mix ecto.migrate
mix phx.server
```

Acesse:
- `http://localhost:4000/dashboard` (login primeiro)

---

## Deploy no Edge (release + Docker)

No runtime do container:
- `DATABASE_PATH=/data/w_core.db` aponta para um arquivo em `VOLUME` (preserva histórico)
- o release roda com `PHX_SERVER=true`

Arquivos relevantes:
- `w_core/Dockerfile`
- `w_core/rel/env.sh.eex`

