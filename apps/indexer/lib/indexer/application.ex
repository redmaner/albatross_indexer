defmodule Indexer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    rpc_url = Application.get_env(:nimiq_rpc, :url)
    rpc_username = Application.get_env(:nimiq_rpc, :username)
    rpc_password = Application.get_env(:nimiq_rpc, :password)
    rpc_auth = rpc_username != "" and rpc_password != ""

    children = [
      # Starts a worker by calling: Indexer.Worker.start_link(arg)
      # {Indexer.Worker, arg}
      {Nimiqex,
       [
         name: :rpc_client,
         url: rpc_url,
         use_auth: rpc_auth,
         username: rpc_username,
         password: rpc_password
       ]},
      {Mongo,
       [
         name: :mongo,
         url: "mongodb://localhost:27017/albatross",
         username: "albatross",
         password: "a safe password here",
         pool_size: 3,
         auth_source: "admin"
       ]},
      Indexer.Processes.Syncer
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Indexer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
