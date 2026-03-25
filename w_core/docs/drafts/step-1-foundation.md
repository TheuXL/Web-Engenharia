# Step 1 - Foundation (Security Perimeter + Telemetry Ecto Model)

Base do sistema: autenticação do operador + modelagem Ecto do domínio `Telemetry` em SQLite (com índices necessários para upsert eficiente).

**Recursos:** `phx.gen.auth` (perímetro de segurança); contextos Ecto `WCore.Telemetry`; tabelas `nodes` e `node_metrics`; `unique_index` para permitir upsert determinístico no write-behind.

---

## Arquitetura do sistema

```mermaid
graph LR
  Op[Operador] -->|login/sessão| Auth[WCore.Accounts + Phoenix Auth]
  Op -->|CRUD/consulta (contextos)| Telemetry[WCore.Telemetry (Ecto)]
  Telemetry --> DB[(SQLite: w_core_dev.db)]

  subgraph "Telemetria (persistência)"
    nodes[nodes<br/>sensor->máquina] --> DB
    node_metrics[node_metrics<br/>estado consolidado] --> DB
  end
```

---

## O que foi implementado

1. **Autenticação (Perímetro de Segurança)**
   - Gereei `mix phx.gen.auth Accounts User users`.
   - Isso criou o contexto `WCore.Accounts`, schemas de `User` e tabelas auxiliares (tokens, etc.), além das rotas e plugs necessários para proteger páginas do painel.

2. **Modelagem Ecto do contexto `Telemetry`**
   - Gereei:
     - `nodes` via `mix phx.gen.context Telemetry Node ...`
     - `node_metrics` via `mix phx.gen.context Telemetry NodeMetric ...`
   - Ajustei as migrações para as invariantes do motor:
     - `nodes.machine_identifier` com `unique_index` (resolução determinística “sensor -> máquina”)
     - `node_metrics.node_id` com `unique_index` (conflito resolvível por sensor para `upsert` no write-behind)

---

## O que mudou na arquitetura

Este passo prepara a divisão em camadas exigida pelo desafio:

1. **Camada de persistência (verdade de longo prazo)**
   - `WCore.Repo` + SQLite armazenam:
     - cadastro estático de máquinas (`nodes`)
     - último estado consolidado (`node_metrics`)

2. **Separação de domínios**
   - `Telemetry` ficou isolado em `WCore.Telemetry`, reduzindo acoplamento com a lógica de autenticação e deixando clara a transição futura para `ETS + OTP` (Passo 2).

---

## Por que isolei o contexto `Telemetry`

- **CQRS/Separation of Concerns**: a persistência será retaguarda (write-behind), enquanto o “lado quente” será movido para ETS depois.
- **Evolução incremental**: no Passo 2, as mudanças ficam concentradas nos processos/ETS, sem reescrever a modelagem do domínio.
- **Testabilidade**: índices e chaves de conflito (base para upsert) ficam governados por um contexto coeso.

---

## Por que SQLite (Edge) com `ecto_sqlite3`

- **Operação simples**: o DB é um arquivo único.
- **Persistência local previsível**: o histórico sobrevive a reinícios quando apontado para volume no container (Passo 5).
- **Lock evitado indiretamente**: o gargalo clássico do DB por escrita síncrona será mitigado no Passo 2 com ETS + write-behind.
- **Restrições do desafio**: sem Postgres/Redis (proibidos).

---

## Arquivos principais

| Arquivo | Papel |
|--------|-------|
| `lib/w_core/telemetry.ex` | Contexto `Telemetry` (consulta/CRUD Ecto) |
| `lib/w_core/telemetry/node.ex` | Schema Ecto de `nodes` |
| `lib/w_core/telemetry/node_metric.ex` | Schema Ecto de `node_metrics` |
| `priv/repo/migrations/*create_nodes*.exs` | `unique_index` em `machine_identifier` |
| `priv/repo/migrations/*create_node_metrics*.exs` | `unique_index` em `node_id` |


