# Step 2 - OTP & ETS (Write-Behind para SQLite)

Hot-path em memória com ETS e ingestão via GenServer, evitando lock do SQLite por evento. Persistência eventual com write-behind e upsert por lote.

**Recursos:** ETS quente (`:w_core_telemetry_cache`); `:ets.update_counter/4`; write-behind assíncrono; upsert via `unique_index(:node_id)`; PubSub incremental (ID + status).

---

## Arquitetura do sistema

```mermaid
graph LR
  HB[Heartbeat de sensor] --> Ingestor[GenServer - WCore.Telemetry.Ingestor]
  Ingestor --> ETS[ETS w_core_telemetry_cache]
  ETS --> Worker[GenServer periódico - WriteBehindWorker ~5s]
  Worker --> SQLite[SQLite - node_metrics]

  Ingestor --> PubSub[PubSub - {:node_status, node_id, status}]
```

---

## O que foi implementado

1. **ETS como camada quente**
   - Criada no boot em `WCore.Application`.
   - Configuração:
     - tipo `:set` (acesso por chave)
     - `:public` + `:named_table`
     - `read_concurrency: true`
   - Layout de tupla:
     - `{node_id, status, event_count, last_payload, timestamp}`

2. **`WCore.Telemetry.Ingestor` (GenServer)**
   - Atualiza ETS no hot-path:
     - `:ets.update_counter/4` para incrementar `event_count`
     - `:ets.insert/2` para status + último payload + timestamp
   - Evita payload grande no PubSub:
     - publica apenas `{:node_status, node_id, status}`

3. **Write-Behind (`WCore.Telemetry.WriteBehindWorker`)**
   - A cada ~5s:
     - faz snapshot com `:ets.tab2list/1`
     - projeta para linhas da tabela `node_metrics`
     - persiste com `Repo.insert_all/3` usando `conflict_target: [:node_id]`

---

## Por que `:set` e não `:ordered_set`?

- Atualizações e leituras são por chave (`node_id`), não por ordenação.
- `:ordered_set` adiciona custo de manutenção de ordenação.
- O objetivo do desafio é latência baixa no hot-path; `:set` minimiza overhead.

---

## Estratégia de backpressure (SQLite mais lento que a ingestão)

- **Hot-path não bloqueia**: o Ingestor não espera DB; só escreve em ETS.
- **Persistência é eventual**: o worker apenas projeta o *estado atual* para o SQLite.
- **Idempotência via upsert**: como `node_metrics.node_id` é `unique_index`, o SQLite resolve conflitos por sensor.
- **Sem perda de eventos no modelo do desafio**:
  - `event_count` é cumulativo em ETS
  - cada flush escreve o total mais recente (ciclos seguintes corrigem se um flush ocorrer “antes” do fim do pico)

Trade-off:
- DB muito lento pode aumentar writes repetidos (flushes sucessivos com o mesmo `node_id`).
- Isso é aceitável porque preserva a propriedade mais crítica: manter o dashboard responsivo e consistente por leitura eventual.

---

## Invariantes de dados (formato ETS e consistência)

- O registro ETS é uma tupla fixa por `node_id`:
  - `{node_id, status, event_count, last_payload, timestamp}`
- `event_count` é cumulativo no ETS e **não é resetado** a cada flush.
- O worker persiste o estado atual (cumulativo) com upsert por `node_id`.
- Timestamps são normalizados para `:utc_datetime` sem microsegundos (truncados para `:second`) para compatibilidade com SQLite/Ecto.

---

## Arquivos principais

| Arquivo | Papel |
|--------|-------|
| `lib/w_core/application.ex` | cria ETS e adiciona os processos ao supervisor |
| `lib/w_core/telemetry/ingestor.ex` | ingestão (update_counter + insert) + PubSub incremental |
| `lib/w_core/telemetry/write_behind_worker.ex` | flush periódico com `insert_all` + upsert |


