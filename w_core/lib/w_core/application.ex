defmodule WCore.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Hot-path cache for telemetry ingestion. Created once at startup.
    #
    # ETS keeps the pipeline write-latency low by avoiding DB locks per event.
    ets_table = :w_core_telemetry_cache
    _ =
      case :ets.whereis(ets_table) do
        :undefined -> :ets.new(ets_table, [:set, :public, :named_table, read_concurrency: true])
        _tid -> :ok
      end

    children = [
      WCoreWeb.Telemetry,
      WCore.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:w_core, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:w_core, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: WCore.PubSub},
      WCore.Telemetry.Ingestor,
      WCore.Telemetry.WriteBehindWorker,
      # Start a worker by calling: WCore.Worker.start_link(arg)
      # {WCore.Worker, arg},
      # Start to serve requests, typically the last entry
      WCoreWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WCore.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WCoreWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
