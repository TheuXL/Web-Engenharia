defmodule WCore.TelemetryFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `WCore.Telemetry` context.
  """

  @doc """
  Generate a node.
  """
  def node_fixture(scope, attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    attrs =
      Enum.into(attrs, %{
        location: "some location-#{unique}",
        machine_identifier: "some machine_identifier-#{unique}"
      })

    {:ok, node} = WCore.Telemetry.create_node(scope, attrs)
    node
  end

  @doc """
  Generate a node_metric.
  """
  def node_metric_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        last_payload: %{},
        last_seen_at: ~U[2026-03-24 14:44:00Z],
        status: "some status",
        total_events_processed: 42
      })

    {:ok, node_metric} = WCore.Telemetry.create_node_metric(scope, attrs)
    node_metric
  end
end
