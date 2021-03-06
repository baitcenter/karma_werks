defmodule KarmaWerks.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      KarmaWerks.Repo,
      # Start the Dgraph client
      {Dlex, [name: KarmaWerks.DgraphProcess]},
      # Start the Telemetry supervisor
      KarmaWerksWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: KarmaWerks.PubSub},
      # Start the Endpoint (http/https)
      KarmaWerksWeb.Endpoint,
      # Start Nebulex Worker
      KarmaWerks.Cache
      # Start a worker by calling: KarmaWerks.Worker.start_link(arg)
      # {KarmaWerks.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: KarmaWerks.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    KarmaWerksWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
