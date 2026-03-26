defmodule WCoreWeb.Router do
  use WCoreWeb, :router

  import WCoreWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WCoreWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :mailbox_enabled do
    plug WCoreWeb.Plugs.EnsureMailboxEnabled
  end

  scope "/api", WCoreWeb do
    pipe_through :api

    post "/telemetry/ingest", TelemetryIngestController, :ingest
  end

  scope "/", WCoreWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/dev" do
    pipe_through [:browser, :mailbox_enabled]
    forward "/mailbox", Plug.Swoosh.MailboxPreview
  end

  scope "/", WCoreWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", WCoreWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", WCoreWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  scope "/", WCoreWeb do
    pipe_through [:browser, :require_authenticated_user]

    live "/dashboard", DashboardLive, :index
  end
end
