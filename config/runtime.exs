import Config

if System.get_env("PHX_SERVER") do
  config :w_core, WCoreWeb.Endpoint, server: true
end

config :w_core, WCoreWeb.Endpoint, http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :prod do
  database_path =
    System.get_env("DATABASE_PATH") ||
      raise """
      environment variable DATABASE_PATH is missing.
      For example: /etc/w_core/w_core.db
      """

  config :w_core, WCore.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "localhost"
  url_scheme = System.get_env("PHX_SCHEME") || "http"
  url_port = String.to_integer(System.get_env("PHX_URL_PORT") || System.get_env("PORT") || "4000")

  config :w_core, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :w_core, WCoreWeb.Endpoint,
    url: [host: host, port: url_port, scheme: url_scheme],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}],
    secret_key_base: secret_key_base

  config :w_core, WCore.Mailer, adapter: Swoosh.Adapters.Local
  config :swoosh, :api_client, false
  config :swoosh, local: true
end
