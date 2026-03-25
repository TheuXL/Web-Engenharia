defmodule WCore.TelemetryTest do
  use WCore.DataCase

  alias WCore.Telemetry

  describe "nodes" do
    alias WCore.Telemetry.Node

    import WCore.AccountsFixtures, only: [user_scope_fixture: 0]
    import WCore.TelemetryFixtures

    @invalid_attrs %{location: nil, machine_identifier: nil}

    test "list_nodes/1 returns all scoped nodes" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      node = node_fixture(scope)
      other_node = node_fixture(other_scope)
      assert Telemetry.list_nodes(scope) == [node]
      assert Telemetry.list_nodes(other_scope) == [other_node]
    end

    test "get_node!/2 returns the node with given id" do
      scope = user_scope_fixture()
      node = node_fixture(scope)
      other_scope = user_scope_fixture()
      assert Telemetry.get_node!(scope, node.id) == node
      assert_raise Ecto.NoResultsError, fn -> Telemetry.get_node!(other_scope, node.id) end
    end

    test "create_node/2 with valid data creates a node" do
      valid_attrs = %{location: "some location", machine_identifier: "some machine_identifier"}
      scope = user_scope_fixture()

      assert {:ok, %Node{} = node} = Telemetry.create_node(scope, valid_attrs)
      assert node.location == "some location"
      assert node.machine_identifier == "some machine_identifier"
      assert node.user_id == scope.user.id
    end

    test "create_node/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Telemetry.create_node(scope, @invalid_attrs)
    end

    test "update_node/3 with valid data updates the node" do
      scope = user_scope_fixture()
      node = node_fixture(scope)
      update_attrs = %{location: "some updated location", machine_identifier: "some updated machine_identifier"}

      assert {:ok, %Node{} = node} = Telemetry.update_node(scope, node, update_attrs)
      assert node.location == "some updated location"
      assert node.machine_identifier == "some updated machine_identifier"
    end

    test "update_node/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      node = node_fixture(scope)

      assert_raise MatchError, fn ->
        Telemetry.update_node(other_scope, node, %{})
      end
    end

    test "update_node/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      node = node_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Telemetry.update_node(scope, node, @invalid_attrs)
      assert node == Telemetry.get_node!(scope, node.id)
    end

    test "delete_node/2 deletes the node" do
      scope = user_scope_fixture()
      node = node_fixture(scope)
      assert {:ok, %Node{}} = Telemetry.delete_node(scope, node)
      assert_raise Ecto.NoResultsError, fn -> Telemetry.get_node!(scope, node.id) end
    end

    test "delete_node/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      node = node_fixture(scope)
      assert_raise MatchError, fn -> Telemetry.delete_node(other_scope, node) end
    end

    test "change_node/2 returns a node changeset" do
      scope = user_scope_fixture()
      node = node_fixture(scope)
      assert %Ecto.Changeset{} = Telemetry.change_node(scope, node)
    end
  end

  describe "node_metrics" do
    alias WCore.Telemetry.NodeMetric

    import WCore.AccountsFixtures, only: [user_scope_fixture: 0]
    import WCore.TelemetryFixtures

    @invalid_attrs %{status: nil, total_events_processed: nil, last_payload: nil, last_seen_at: nil}

    test "list_node_metrics/1 returns all scoped node_metrics" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      node_metric = node_metric_fixture(scope)
      other_node_metric = node_metric_fixture(other_scope)
      assert Telemetry.list_node_metrics(scope) == [node_metric]
      assert Telemetry.list_node_metrics(other_scope) == [other_node_metric]
    end

    test "get_node_metric!/2 returns the node_metric with given id" do
      scope = user_scope_fixture()
      node_metric = node_metric_fixture(scope)
      other_scope = user_scope_fixture()
      assert Telemetry.get_node_metric!(scope, node_metric.id) == node_metric
      assert_raise Ecto.NoResultsError, fn -> Telemetry.get_node_metric!(other_scope, node_metric.id) end
    end

    test "create_node_metric/2 with valid data creates a node_metric" do
      valid_attrs = %{status: "some status", total_events_processed: 42, last_payload: %{}, last_seen_at: ~U[2026-03-24 14:44:00Z]}
      scope = user_scope_fixture()

      assert {:ok, %NodeMetric{} = node_metric} = Telemetry.create_node_metric(scope, valid_attrs)
      assert node_metric.status == "some status"
      assert node_metric.total_events_processed == 42
      assert node_metric.last_payload == %{}
      assert node_metric.last_seen_at == ~U[2026-03-24 14:44:00Z]
      assert node_metric.user_id == scope.user.id
    end

    test "create_node_metric/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Telemetry.create_node_metric(scope, @invalid_attrs)
    end

    test "update_node_metric/3 with valid data updates the node_metric" do
      scope = user_scope_fixture()
      node_metric = node_metric_fixture(scope)
      update_attrs = %{status: "some updated status", total_events_processed: 43, last_payload: %{}, last_seen_at: ~U[2026-03-25 14:44:00Z]}

      assert {:ok, %NodeMetric{} = node_metric} = Telemetry.update_node_metric(scope, node_metric, update_attrs)
      assert node_metric.status == "some updated status"
      assert node_metric.total_events_processed == 43
      assert node_metric.last_payload == %{}
      assert node_metric.last_seen_at == ~U[2026-03-25 14:44:00Z]
    end

    test "update_node_metric/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      node_metric = node_metric_fixture(scope)

      assert_raise MatchError, fn ->
        Telemetry.update_node_metric(other_scope, node_metric, %{})
      end
    end

    test "update_node_metric/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      node_metric = node_metric_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Telemetry.update_node_metric(scope, node_metric, @invalid_attrs)
      assert node_metric == Telemetry.get_node_metric!(scope, node_metric.id)
    end

    test "delete_node_metric/2 deletes the node_metric" do
      scope = user_scope_fixture()
      node_metric = node_metric_fixture(scope)
      assert {:ok, %NodeMetric{}} = Telemetry.delete_node_metric(scope, node_metric)
      assert_raise Ecto.NoResultsError, fn -> Telemetry.get_node_metric!(scope, node_metric.id) end
    end

    test "delete_node_metric/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      node_metric = node_metric_fixture(scope)
      assert_raise MatchError, fn -> Telemetry.delete_node_metric(other_scope, node_metric) end
    end

    test "change_node_metric/2 returns a node_metric changeset" do
      scope = user_scope_fixture()
      node_metric = node_metric_fixture(scope)
      assert %Ecto.Changeset{} = Telemetry.change_node_metric(scope, node_metric)
    end
  end
end
