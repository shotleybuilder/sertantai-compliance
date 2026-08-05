defmodule SertantaiComplianceWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :sertantai_compliance

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_sertantai_compliance_key",
    signing_salt: "m2DMKQLC",
    same_site: "Lax"
  ]

  # socket "/live", Phoenix.LiveView.Socket,
  #   websocket: [connect_info: [session: @session_options]],
  #   longpoll: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :sertantai_compliance,
    gzip: false,
    only: SertantaiComplianceWeb.static_paths()

  # Tidewave MCP server for AI assistant integration
  # Available at http://localhost:4000/tidewave/mcp
  if Code.ensure_loaded?(Tidewave) do
    plug Tidewave
  end

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :sertantai_compliance
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options

  # CORS configuration — use string origins only (regexes contain NIF
  # references that fail compile-time escaping in MIX_ENV=prod)
  plug Corsica,
    origins: [
      "http://localhost:5176",
      "http://localhost:5173",
      "http://127.0.0.1:5176",
      "http://127.0.0.1:5173",
      System.get_env("FRONTEND_URL") || ""
    ],
    allow_credentials: true,
    allow_headers: ["content-type", "authorization"],
    max_age: 600

  plug SertantaiComplianceWeb.Router
end
