defmodule WCore.Telemetry.Ingestor do
  use GenServer

  require Logger

  @ets_table :w_core_telemetry_cache
  @pubsub_topic "w_core:telemetry:node_updates"

  @type ingest_event :: %{
          required(:node_id) => integer(),
          required(:status) => String.t(),
          required(:payload) => map(),
          required(:timestamp) => DateTime.t()
        }

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Ingesta um evento de telemetria (fire-and-forget).

  Espera um mapa com `node_id`, `status`, `payload` e `timestamp`.
  """
  @spec ingest(ingest_event()) :: :ok
  def ingest(%{node_id: node_id, status: status, payload: payload, timestamp: ts}) do
    GenServer.cast(__MODULE__, {:ingest, node_id, status, payload, ts})
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_cast({:ingest, node_id, status, payload, ts}, state)
      when is_integer(node_id) and is_binary(status) and is_map(payload) and is_struct(ts, DateTime) do
    ts = DateTime.truncate(ts, :second)

    new_count = :ets.update_counter(@ets_table, node_id, {3, 1}, {node_id, status, 0, payload, ts})

    :ets.insert(@ets_table, {node_id, status, new_count, payload, ts})

    Phoenix.PubSub.broadcast(WCore.PubSub, @pubsub_topic, {:node_status, node_id, status})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:ingest, node_id, status, payload, ts}, state) do
    Logger.warning("""
    Ignorando evento de telemetria inválido.
    node_id=#{inspect(node_id)} status=#{inspect(status)} payload_type=#{inspect(payload)} ts=#{inspect(ts)}
    """)

    {:noreply, state}
  end
end

