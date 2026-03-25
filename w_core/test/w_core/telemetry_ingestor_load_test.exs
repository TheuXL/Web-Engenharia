defmodule WCore.TelemetryIngestorLoadTest do
  use WCore.DataCase, async: false

  import WCore.AccountsFixtures, only: [user_scope_fixture: 0]
  import WCore.TelemetryFixtures

  alias WCore.Repo
  alias WCore.Telemetry.NodeMetric

  @ets_table :w_core_telemetry_cache

  defp wait_until(fun, timeout_ms) when is_function(fun, 0) do
    start = System.monotonic_time(:millisecond)

    do_wait_until(fun, start, timeout_ms)
  end

  defp do_wait_until(fun, start, timeout_ms) do
    if fun.() do
      :ok
    else
      if System.monotonic_time(:millisecond) - start > timeout_ms do
        :timeout
      else
        Process.sleep(50)
        do_wait_until(fun, start, timeout_ms)
      end
    end
  end

  setup do
    # Garante que a aplicação (e portanto ETS + supervisores) está rodando.
    {:ok, _} = Application.ensure_all_started(:w_core)

    # Permite que o write-behind worker use a conexão do sandbox do teste.
    owner = self()
    worker_pid = Process.whereis(WCore.Telemetry.WriteBehindWorker)
    Ecto.Adapters.SQL.Sandbox.allow(WCore.Repo, owner, worker_pid)

    # Limpa o ETS entre testes para evitar contaminação.
    :ets.delete_all_objects(@ets_table)

    :ok
  end

  test "10k ingestões concorrentes persistem sem perda" do
    scope = user_scope_fixture()
    node = node_fixture(scope)

    node_id = node.id

    ts = DateTime.utc_now(:second)
    event = %{node_id: node_id, status: "ok", payload: %{}, timestamp: ts}

    tasks =
      1..10_000
      |> Task.async_stream(
        fn _ ->
          WCore.Telemetry.Ingestor.ingest(event)
          :ok
        end,
        max_concurrency: 5_000,
        timeout: :infinity
      )
      |> Enum.to_list()

    assert Enum.all?(tasks, fn
             {:ok, :ok} -> true
             _ -> false
           end)

    assert :ok =
             wait_until(
               fn ->
                 case :ets.lookup(@ets_table, node_id) do
                   [{^node_id, _status, event_count, _payload, _ts}] -> event_count == 10_000
                   _ -> false
                 end
               end,
               10_000
             )

    # SQLite é write-behind: esperamos o worker persistir após o pico.
    assert :ok =
             wait_until(
               fn ->
                 metric =
                   Repo.one(
                     from(m in NodeMetric, where: m.node_id == ^node_id, select: m.total_events_processed)
                   )

                 metric == 10_000
               end,
               30_000
             )
  end

  test "ETS sobrevive à morte/restart do Ingestor" do
    scope = user_scope_fixture()
    node = node_fixture(scope)

    node_id = node.id

    ts = DateTime.utc_now(:second)
    event = %{node_id: node_id, status: "ok", payload: %{}, timestamp: ts}

    for _ <- 1..100 do
      WCore.Telemetry.Ingestor.ingest(event)
    end

    assert :ok =
             wait_until(
               fn ->
                 case :ets.lookup(@ets_table, node_id) do
                   [{^node_id, _status, event_count, _payload, _ts}] -> event_count == 100
                   _ -> false
                 end
               end,
               10_000
             )

    ingestor_pid = Process.whereis(WCore.Telemetry.Ingestor)
    Process.exit(ingestor_pid, :kill)

    # Espera o supervisor recriar o processo do Ingestor.
    assert :ok =
             wait_until(
               fn -> Process.whereis(WCore.Telemetry.Ingestor) != nil end,
               10_000
             )

    # Dá tempo para o GenServer reiniciado esvaziar mailbox inicial.
    Process.sleep(200)

    # O ETS deve continuar com o mesmo contador.
    assert :ok =
             wait_until(
               fn ->
                 case :ets.lookup(@ets_table, node_id) do
                   [{^node_id, _status, event_count, _payload, _ts}] -> event_count == 100
                   _ -> false
                 end
               end,
               10_000
             )

    for _ <- 1..50 do
      WCore.Telemetry.Ingestor.ingest(event)
    end

    assert :ok =
             wait_until(
               fn ->
                 case :ets.lookup(@ets_table, node_id) do
                   [{^node_id, _status, event_count, _payload, _ts}] -> event_count == 150
                   _ -> false
                 end
               end,
               20_000
             )
  end
end

