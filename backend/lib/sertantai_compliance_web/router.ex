defmodule SertantaiComplianceWeb.Router do
  use SertantaiComplianceWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
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
  end
end
