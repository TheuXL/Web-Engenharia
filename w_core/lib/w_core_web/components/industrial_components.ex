defmodule WCoreWeb.IndustrialComponents do
  @moduledoc """
  Componentes visuais do painel industrial (HEEx puros).

  O objetivo aqui é ser semântico e leve: renderização e estados reativos
  via LiveView, sem depender de bibliotecas de UI pesadas.
  """

  use Phoenix.Component

  @doc """
  Card de máquina com status e contador cumulativo de eventos.
  """
  attr :node_id, :integer, required: true
  attr :status, :string, required: true
  attr :event_count, :integer, required: true

  def machine_card(assigns) do
    status_class =
      case assigns.status do
        "ok" -> "bg-emerald-500/15 text-emerald-200 border-emerald-400/30"
        "warning" -> "bg-amber-500/15 text-amber-200 border-amber-400/30"
        "error" -> "bg-rose-500/15 text-rose-200 border-rose-400/30"
        _ -> "bg-slate-500/10 text-base-content/80 border-base-content/20"
      end

    assigns = assign(assigns, :status_class, status_class)

    ~H"""
    <div class="rounded-lg border border-base-content/10 p-4 shadow-sm">
      <div class="flex items-start justify-between gap-4">
        <div class="min-w-0">
          <div class="text-sm text-base-content/70">Máquina</div>
          <div class="font-semibold truncate">#{@node_id}</div>
        </div>
        <div class={["rounded-full px-3 py-1 text-xs border", @status_class]}>
          #{@status}
        </div>
      </div>

      <div class="mt-3 flex items-end justify-between">
        <div>
          <div class="text-xs text-base-content/60">Eventos processados</div>
          <div class="text-2xl font-bold tabular-nums">#{@event_count}</div>
        </div>
        <div class="text-xs text-base-content/50">tempo real</div>
      </div>
    </div>
    """
  end
end

