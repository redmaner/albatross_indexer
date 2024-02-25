defmodule Indexer.Processes.Syncer do
  require Logger
  use GenServer

  def init(_) do
    state = %{}
    {:ok, state, {:continue, :check_status}}
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: {:global, __MODULE__})
  end

  def handle_continue(:check_status, state) do
    case Indexer.Model.Syncer.get_state() do
      {:error, reason} ->
        Logger.error("Error when retrieving state: #{inspect(reason)}")
        {:shutdown, reason}

      %{docs: docs} when docs == [] ->
        Logger.info("Got empty cursor")
        {:noreply, state, {:continue, :init_state}}

      cursor ->
        Logger.info("Got a cursor: #{inspect(cursor)}")
        {:noreply, state}
    end
  end

  def handle_continue(:init_state, state) do
    case Indexer.Model.Syncer.init_state() do
      :ok -> Logger.info("init state success")
      something -> Logger.error("Unexpected case when init state: #{inspect(something)}")
    end

    {:noreply, state}
  end
end
