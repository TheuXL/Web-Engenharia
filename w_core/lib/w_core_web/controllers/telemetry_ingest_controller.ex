defmodule WCoreWeb.TelemetryIngestController do
  use WCoreWeb, :controller

  # Aceita um heartbeat JSON e encaminha para o Ingestor (ETS hot-path).
  #
  # Esperado (exemplo):
  # {
  #   "node_id": 123,
  #   "status": "ok",
  #   "payload": { "temp": 42.3 },
  #   "timestamp": "2026-03-25T14:00:00Z"  // opcional
  # }
  def ingest(conn, params) do
    with {:ok, node_id} <- parse_int(params["node_id"] || params[:node_id]),
         {:ok, status} <- parse_string(params["status"] || params[:status]),
         {:ok, payload} <- parse_map(params["payload"] || params[:payload] || %{}),
         {:ok, ts} <- parse_timestamp(params["timestamp"] || params[:timestamp]) do
      WCore.Telemetry.Ingestor.ingest(%{
        node_id: node_id,
        status: status,
        payload: payload,
        timestamp: ts
      })

      conn
      |> put_status(:accepted)
      |> json(%{ok: true})
    else
      {:error, :invalid_payload} ->
        conn |> put_status(:bad_request) |> json(%{ok: false, error: "invalid payload"})

      {:error, :invalid_timestamp} ->
        conn |> put_status(:bad_request) |> json(%{ok: false, error: "invalid timestamp"})

      {:error, :invalid_type} ->
        conn |> put_status(:bad_request) |> json(%{ok: false, error: "invalid types"})

      :error ->
        conn |> put_status(:bad_request) |> json(%{ok: false, error: "invalid params"})
    end
  end

  defp parse_int(nil), do: {:error, :invalid_type}
  defp parse_int(v) when is_integer(v), do: {:ok, v}
  defp parse_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {i, ""} -> {:ok, i}
      _ -> {:error, :invalid_type}
    end
  end

  defp parse_int(_), do: {:error, :invalid_type}

  defp parse_string(nil), do: {:error, :invalid_type}
  defp parse_string(v) when is_binary(v), do: {:ok, v}
  defp parse_string(_), do: {:error, :invalid_type}

  defp parse_map(v) when is_map(v), do: {:ok, v}
  defp parse_map(_), do: {:error, :invalid_payload}

  defp parse_timestamp(nil), do: {:ok, DateTime.utc_now(:second)}

  defp parse_timestamp(v) when is_binary(v) do
    case DateTime.from_iso8601(v) do
      {:ok, dt, _offset} -> {:ok, DateTime.truncate(dt, :second)}
      _ -> {:error, :invalid_timestamp}
    end
  end

  defp parse_timestamp(_), do: {:error, :invalid_timestamp}
end

