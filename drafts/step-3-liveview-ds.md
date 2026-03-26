# Step 3 - LiveView Dashboard (Design System + PubSub Estratégico)

Dashboard em tempo real para operadores: leitura quente no ETS + updates incrementais via PubSub, com componentes HEEx semânticos.

**Recursos:** LiveView com snapshot inicial via ETS; PubSub incremental (`node_id + status`); atualização granular por máquina (evita re-render de toda lista); componentes HEEx para cards.

---

## Arquitetura do sistema

```mermaid
graph LR
  ETS[ETS w_core_telemetry_cache] --> LV["LiveView (DashboardLive)"]
  PubSub[Phoenix.PubSub] -->|"node_status (node_id, status)"| LV
  LV --> UI[Componentes HEEx - machine_card]
```

---

## O que foi implementado

1. **Componentes HEEx semânticos**
   - `WCoreWeb.IndustrialComponents.machine_card/1` renderiza:
     - `node_id`
     - `status`
     - `event_count`

2. **LiveView do dashboard**
   - `mount/3`:
     - subscreve no tópico do PubSub
     - carrega o snapshot inicial da ETS (rápido, sem DB)

3. **Atualização incremental**
   - O Ingestor publica `{:node_status, node_id, status}`.
   - O LiveView atualiza somente o card afetado:
     - usa `:ets.lookup/2` para obter o `event_count` mais recente
     - ajusta `assigns.machines` no `node_id` correspondente

4. **Rota protegida**
   - A rota `/dashboard` está sob `:require_authenticated_user`.

---

## Estado no LiveView vs estado no ETS

- **ETS** é a fonte de verdade quente:
  - agregações por `node_id`
  - contagem cumulativa
  - último status e último payload

- **LiveView** mantém apenas um cache de leitura:
  - `assigns.machines` (map por `node_id`)
  - `assigns.node_ids` para renderização estável

Isso evita que o dashboard dependa do tempo de resposta do SQLite para “piscar” em tempo real.

---

## Como evitamos over-rendering

- `node_ids` fica estável (a lista só muda quando surge um novo `node_id`).
- cards têm ids determinísticos no DOM (`machine-#{node_id}` no wrapper).
- o PubSub envia payload mínimo (sem payload completo).

---

## Arquivos principais

| Arquivo | Papel |
|----------|-------|
| `lib/w_core_web/live/dashboard_live.ex` | LiveView: snapshot inicial via ETS e atualização incremental via PubSub |
| `lib/w_core_web/components/industrial_components.ex` | Componentes HEEx: cards/labels sem dependências pesadas |

---

## Explicação detalhada do código (Step 3)

### `lib/w_core_web/live/dashboard_live.ex`
- `mount/3`:
  - valida contexto de sessão (rota protegida no router);
  - assina tópico PubSub da telemetria;
  - carrega snapshot atual da ETS para evitar tela "vazia" na primeira renderização.
- `handle_info/2`:
  - recebe mensagem compacta do PubSub (`node_id`, `status`);
  - consulta ETS para pegar `event_count` mais novo;
  - atualiza apenas a entrada da máquina afetada no `assigns`.
- Benefício: menor dif de DOM e melhor responsividade quando há muitos sensores.

### `lib/w_core_web/components/industrial_components.ex`
- Define `machine_card/1` como componente reutilizável.
- Concentra regras visuais de status (classes, badges e semântica do card).
- Mantém consistência visual do dashboard e simplifica manutenção da view.

### Template HEEx do dashboard
- Renderiza lista estável de máquinas com ids determinísticos por `node_id`.
- IDs estáveis ajudam o LiveView a reconciliar patches sem remontar toda a árvore HTML.
- A tela exibe feedback claro quando ainda não há heartbeat ("Nenhuma máquina ainda").

### Router e autenticação no contexto de UI
- `/dashboard` passa por `:require_authenticated_user`.
- Usuário anônimo é redirecionado para login.
- Usuário autenticado acessa atualização em tempo real sem polling no browser.



