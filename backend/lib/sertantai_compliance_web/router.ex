defmodule SertantaiComplianceWeb.Router do
  use SertantaiComplianceWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth do
    plug SertantaiComplianceWeb.AuthPlug
  end

  # Health check endpoints (no /api prefix, no authentication required)
  scope "/", SertantaiComplianceWeb do
    pipe_through :api
    get "/health", HealthController, :index
    get "/health/detailed", HealthController, :show
  end

  # API endpoints
  scope "/api", SertantaiComplianceWeb do
    pipe_through :api
    get "/hello", HelloController, :index

    # ElectricSQL Gatekeeper proxy — injects ELECTRIC_SECRET server-side
    get "/electric/v1/shape", ElectricProxyController, :shape
    delete "/electric/v1/shape", ElectricProxyController, :delete_shape
  end

  # Authenticated screening API
  scope "/api/screening", SertantaiComplianceWeb do
    pipe_through [:api, :auth]

    # Applicabilities
    get "/applicabilities", ScreeningController, :index
    put "/applicabilities/:law_name", ScreeningController, :upsert
    post "/applicabilities/bulk", ScreeningController, :bulk_upsert

    # Stats
    get "/stats", ScreeningController, :stats

    # Sync
    post "/sync", ScreeningController, :trigger_sync

    # Events
    get "/events", ScreeningController, :events
    get "/events/:law_name", ScreeningController, :law_events
    post "/undo", ScreeningController, :undo

    # Profile
    get "/profile", ScreeningController, :get_profile
    put "/profile", ScreeningController, :upsert_profile
    get "/vocabulary", ScreeningController, :vocabulary

    # Evaluation (fitness engine)
    post "/evaluate", ScreeningController, :evaluate
    get "/questions", ScreeningController, :questions

    # Change management
    get "/changes/summary", ScreeningController, :changes_summary
    get "/changes", ScreeningController, :changes_list
    put "/changes/:id/decide", ScreeningController, :decide_change

    # Debug (dev only)
    post "/debug-dump", ScreeningController, :debug_dump

    # Provisions (drill-down)
    get "/laws/:law_name/provisions", ScreeningController, :provisions

    # Definitions (legal term interpretations)
    get "/definitions", ScreeningController, :definitions

    # Compliance metrics
    get "/compliance-metrics", ScreeningController, :compliance_metrics
  end
end
