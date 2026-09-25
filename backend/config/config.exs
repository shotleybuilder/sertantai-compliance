# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Required since Ash 3.33. Codepoints match how Postgres counts length, so
# max_length validation agrees with the database.
config :ash, default_string_length_count: :codepoints

# Background jobs. Change detection runs daily at 05:00 UTC.
config :sertantai_compliance, Oban,
  repo: SertantaiCompliance.Repo,
  queues: [default: 5],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 14},
    {Oban.Plugins.Cron,
     crontab: [{"0 5 * * *", SertantaiCompliance.Sync.Workers.ChangeDetectionWorker}]}
  ]

config :sertantai_compliance,
  ecto_repos: [SertantaiCompliance.Repo],
  ash_domains: [SertantaiCompliance.Api, SertantaiCompliance.Sync],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :sertantai_compliance, SertantaiComplianceWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: SertantaiComplianceWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: SertantaiCompliance.PubSub,
  live_view: [signing_salt: "xjXQzhFq"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
