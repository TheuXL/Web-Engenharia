# Step 4 - Testes Rigorosos (Carga, Corridas e Resiliência)

Evidência executável de “missão crítica”: carga concorrente (10.000 ingestões), consistência do contador no ETS e sincronização eventual no SQLite; além de teste de resiliência ao restart do Ingestor.

**Recursos:** `Task.async_stream` para pressão; validação de invariantes com `polling` (eventual consistency do write-behind); prova de que a ETS sobrevive ao restart do GenServer.

---

## O que foi testado

Criei `test/w_core/telemetry_ingestor_load_test.exs` com 2 cenários:

1. **Carga concorrente (10.000 ingestões)**
   - muitas tasks disparam ingestão ao mesmo tempo
   - o Ingestor (GenServer) serializa a atualização do ETS
   - valida:
     - `event_count == 10_000` no ETS
     - `node_metrics.total_events_processed == 10_000` no SQLite (quando o worker flushar)

2. **Resiliência do Supervisor (morte/restart do Ingestor)**
   - injeta eventos, mata o `WCore.Telemetry.Ingestor` e espera o processo voltar
   - valida que:
     - o contador no ETS mantém o valor anterior
     - após novos eventos, o contador continua incremental (ex.: 100 -> 150)

---

## Asserções principais (invariantes)

- **ETS nunca perde contagem**
  - o contador é cumulativo e atualizado no hot-path.

- **SQLite sincroniza (eventual)**
  - o teste não assume um tempo fixo.
  - usa polling até o valor consolidado aparecer em `node_metrics`.

---

## Como lidamos com race conditions

1. **Eventos vs flush do worker**
   - o worker faz snapshot (`:ets.tab2list/1`) e persiste em lote.
   - o teste usa polling para tolerar “janela” de eventual consistency.

2. **Concorrência na ingestão**
   - apesar de muitas tasks enviarem ao mesmo tempo, a escrita no ETS acontece apenas no GenServer.
   - isso remove race condition de escrita em ETS (atualização serial).

3. **Restart do Ingestor**
   - a ETS não é criada/recriada dentro do Ingestor.
   - ela é criada no boot (`WCore.Application.start/2`), então continua existindo mesmo após reiniciar o Ingestor.

---

## Detalhe importante: SQL Sandbox no teste

Nos testes o Ecto usa sandbox (`config/test.exs`).
Como o write-behind worker roda em processo separado, o teste libera o acesso com:

- `Ecto.Adapters.SQL.Sandbox.allow/3`

para permitir que o worker também utilize a conexão do sandbox do teste.

---

## Arquivo de teste

| Arquivo | Papel |
|----------|------|
| `test/w_core/telemetry_ingestor_load_test.exs` | carga concorrente + resiliência + sincronização eventual |

---

## Por que o teste usa polling

O write-behind é assíncrono e só sincroniza o SQLite periodicamente (flush do `WriteBehindWorker`).
Por isso o teste valida primeiro o estado no ETS (consistência imediata) e depois aguarda o SQLite “convergir” via polling.

Essa abordagem evita flakiness e reflete o comportamento do sistema em produção (eventual consistency por design).

---

## Explicação detalhada do código de testes (Step 4)

### `test/w_core/telemetry_ingestor_load_test.exs`
- Organiza os cenários com foco em comportamento observável, não em implementação interna.
- Em carga concorrente:
  - dispara muitas ingestões em paralelo com `Task.async_stream`;
  - confirma convergência do contador em ETS;
  - confirma convergência eventual no SQLite.
- Em resiliência:
  - força queda do processo `Ingestor`;
  - espera restart supervisionado;
  - valida que o contador continua cumulativo.

### Helpers de polling
- Fazem retry com timeout total e intervalos curtos.
- São necessários porque write-behind é temporal (depende da janela de flush).
- Sem polling, o teste tende a ficar frágil e dependente de timing da máquina/CI.

### Sandbox e processos concorrentes
- O teste explicitamente permite acesso de processos filhos (`allow/3`) para o worker escrever no banco.
- Isso evita falso negativo onde a lógica está correta, mas o processo secundário fica bloqueado pelo sandbox.

### Resultado arquitetural validado
- O hot-path mantém latência e não espera disco.
- O sistema sobrevive a falhas parciais (restart de worker).
- O estado final persiste de forma consistente no banco, respeitando o modelo eventual.

---

## Estratégia de qualidade adotada

- **Invariantes primeiro**: testes focam propriedades do sistema, não detalhe de implementação.
- **Assíncrono explícito**: polling e timeouts tornam o comportamento eventual testável sem flakiness.
- **Falha como cenário principal**: restart de processo supervisionado validado como caminho normal de operação.
- **Concorrência realista**: `Task.async_stream` aproxima o comportamento de burst de sensores em produção.

---

## Possíveis melhorias e adaptações

- **Teste de longa duração**: soak test para validar estabilidade por horas (leak, degradação, drift).
- **Teste de caos em persistência**: simular DB lento/bloqueado e medir recuperação pós-normalização.
- **Benchmarks repetíveis**: baseline de throughput/p95/p99 para comparação entre versões.
- **Contract tests da API**: validação formal do payload de ingestão para versões futuras de sensor firmware.
- **Matriz CI**: rodar testes em diferentes limites de CPU/memória para perfis edge variados.

