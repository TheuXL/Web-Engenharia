defmodule WCoreWeb.Plugs.EnsureMailboxEnabled do
  @moduledoc false
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if System.get_env("ENABLE_MAILBOX") == "true" do
      conn
    else
      conn
      |> send_resp(:not_found, "Not Found")
      |> halt()
    end
  end
end

