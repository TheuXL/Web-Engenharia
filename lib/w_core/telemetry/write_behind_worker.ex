defmodule WCore.Telemetry.WriteBehindWorker do
  use GenServer

  require Logger

  import Ecto.Query, warn: false

  alias WCore.Repo
  alias WCore.Telemetry.Node
  alias WCore.Telemetry.NodeMetric

  @ets_table :w_core_telemetry_cache
  @interval_ms 5_000

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    schedule_flush()
    {:ok, state}
  end

  @impl true
  def handle_info(:flush, state) do
    flush_metrics()
    schedule_flush()
    {:noreply, state}
  end

  defp schedule_flush do
    Process.send_after(self(), :flush, @interval_ms)
  end

  defp flush_metrics do
    rows =
      :ets.tab2list(@ets_table)
      |> Enum.map(fn {node_id, status, event_count, last_payload, last_seen_at} ->
        now = DateTime.utc_now(:second)
        last_seen_at = DateTime.truncate(last_seen_at, :second)

        %{
          node_id: node_id,
          status: status,
          total_events_processed: event_count,
          last_payload: last_payload,
          last_seen_at: last_seen_at,
          user_id: nil,
          inserted_at: now,
          updated_at: now
        }
      end)

    if rows == [] do
      :ok
    else
      persist_rows(rows)
    end
  end

  defp persist_rows(rows) do
    existing_node_ids =
      rows
      |> Enum.map(& &1.node_id)
      |> then(fn ids ->
        Repo.all(from n in Node, where: n.id in ^ids, select: n.id)
      end)
      |> MapSet.new()

    rows = Enum.filter(rows, fn r -> MapSet.member?(existing_node_ids, r.node_id) end)

    if rows == [] do
      :ok
    else
    Repo.insert_all(
      NodeMetric,
      rows,
      on_conflict: {:replace_all_except, [:id, :node_id, :user_id]},
      conflict_target: [:node_id]
    )
    end
  rescue
    e ->
      Logger.error("Falha ao persistir metrics no SQLite: #{Exception.message(e)}")
      :error
  end
end

