defmodule Rephi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RephiWeb.Telemetry,
      Rephi.Repo,
      {DNSCluster, query: Application.get_env(:rephi, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Rephi.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Rephi.Finch},
      # Start a worker by calling: Rephi.Worker.start_link(arg)
      # {Rephi.Worker, arg},
      # Start to serve requests, typically the last entry
      RephiWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Rephi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RephiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
