defmodule WCoreWeb.DashboardLive do
  use WCoreWeb, :live_view

  @ets_table :w_core_telemetry_cache
  @pubsub_topic "w_core:telemetry:node_updates"

  @impl true
  def mount(_params, _session, socket) do
    Phoenix.PubSub.subscribe(WCore.PubSub, @pubsub_topic)

    machines =
      @ets_table
      |> :ets.tab2list()
      |> Enum.reduce(%{}, fn {node_id, status, event_count, _last_payload, _ts}, acc ->
        Map.put(acc, node_id, %{status: status, event_count: event_count})
      end)

    node_ids = machines |> Map.keys() |> Enum.sort()

    {:ok,
     assign(socket,
       machines: machines,
       node_ids: node_ids
     )}
  end

  @impl true
  def handle_info({:node_status, node_id, status}, socket) do
    node_ids = socket.assigns.node_ids
    machines = socket.assigns.machines

    {machines, node_ids} =
      case :ets.lookup(@ets_table, node_id) do
        [{^node_id, ^status, event_count, _last_payload, _ts}] ->
          new_machine = %{status: status, event_count: event_count}
          machines = Map.put(machines, node_id, new_machine)
          {machines, node_ids}

        [{^node_id, _old_status, event_count, _last_payload, _ts}] ->
          new_machine = %{status: status, event_count: event_count}
          machines = Map.put(machines, node_id, new_machine)
          new_node_ids = if Map.has_key?(machines, node_id), do: node_ids, else: Enum.sort(node_ids ++ [node_id])
          {machines, new_node_ids}

        [] ->
          # Em teoria a ETS deveria existir. Caso não exista (race rara), evitamos quebrar a UI.
          new_machine = %{status: status, event_count: 0}
          machines = Map.put(machines, node_id, new_machine)
          {machines, Enum.sort(node_ids ++ [node_id])}
      end

    {:noreply, assign(socket, machines: machines, node_ids: node_ids)}
  end
end

