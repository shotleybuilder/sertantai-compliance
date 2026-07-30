defmodule SertantaiCompliance.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SertantaiComplianceWeb.Telemetry,
      SertantaiCompliance.Repo,
      {DNSCluster,
       query: Application.get_env(:sertantai_compliance, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SertantaiCompliance.PubSub},
      SertantaiCompliance.Auth.JwksClient,
      SertantaiComplianceWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SertantaiCompliance.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SertantaiComplianceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
