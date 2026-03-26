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
    {status_class, status_label, accent_class} =
      case assigns.status do
        "ok" ->
          {"bg-emerald-500/15 text-emerald-200 border-emerald-400/30", "Operando", "from-emerald-400/80 to-emerald-300/10"}

        "warning" ->
          {"bg-amber-500/15 text-amber-200 border-amber-400/30", "Atenção", "from-amber-400/80 to-amber-300/10"}

        "critical" ->
          {"bg-rose-500/15 text-rose-200 border-rose-400/30", "Crítico", "from-rose-500/80 to-rose-300/10"}

        "error" ->
          {"bg-rose-500/15 text-rose-200 border-rose-400/30", "Crítico", "from-rose-500/80 to-rose-300/10"}

        _ ->
          {"bg-slate-500/10 text-base-content/80 border-base-content/20", "Indefinido", "from-base-content/40 to-base-content/5"}
      end

    assigns =
      assigns
      |> assign(:status_class, status_class)
      |> assign(:status_label, status_label)
      |> assign(:accent_class, accent_class)

    ~H"""
    <article class="group relative overflow-hidden rounded-xl border border-base-content/15 bg-base-200/50 p-4 shadow-sm transition hover:border-base-content/25 hover:shadow-md">
      <div class={["pointer-events-none absolute inset-x-0 top-0 h-1 bg-gradient-to-r", @accent_class]}></div>

      <div class="flex items-start justify-between gap-4">
        <div class="min-w-0 space-y-1">
          <p class="text-[11px] uppercase tracking-wider text-base-content/55">Máquina</p>
          <p class="truncate text-lg font-semibold">##{@node_id}</p>
        </div>

        <div class={["inline-flex items-center gap-1 rounded-full px-3 py-1 text-[11px] font-semibold uppercase tracking-wide border", @status_class]}>
          <span class="h-1.5 w-1.5 rounded-full bg-current"></span>
          {@status_label}
        </div>
      </div>

      <div class="mt-5 flex items-end justify-between gap-3">
        <div>
          <p class="text-xs uppercase tracking-wider text-base-content/55">Eventos processados</p>
          <p class="text-3xl font-black leading-none tabular-nums">#{@event_count}</p>
        </div>

        <div class="text-right">
          <p class="text-[11px] text-base-content/50">status técnico</p>
          <p class="text-xs font-medium text-base-content/80">{@status}</p>
        </div>
      </div>
    </article>
    """
  end
end

