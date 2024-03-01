defmodule Indexer.Processes.LiveSyncer do
  require Logger
  use GenServer

  def init(_) do
    state = %{cursor: 0}
    {:ok, state, {:continue, :check_status}}
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: {:global, __MODULE__})
  end

  def handle_continue(:check_status, state) do
    case Indexer.Model.Syncer.get_live_state() do
      {:error, reason} ->
        Logger.error("Error when retrieving state: #{inspect(reason)}")
        {:shutdown, reason}

      %{docs: docs} when docs == [] ->
        Logger.info("Got empty cursor")
        {:noreply, state, {:continue, :init_state}}

      %{docs: [%{"cursor" => cursor}]} ->
        Logger.info("Got a cursor: #{inspect(cursor)}")
        Process.send(self(), :check_height, [])

        {:noreply, %{state | cursor: cursor}}
    end
  end

  def handle_continue(:init_state, state) do
    with {:ok, number} <- get_current_height(),
         :ok <- Indexer.Model.Syncer.init_live_state(number) do
      Logger.info("Initialised new state")

      Process.send(self(), :check_height, [])

      {:noreply, %{state | cursor: number}}
    else
      {:error, reason} ->
        Logger.error("encountered error initializing state: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  def handle_info(:check_height, state) do
    get_current_height()
    |> should_sync_new_blocks?(state)
  end

  def should_sync_new_blocks?({:error, reason}, state) do
    Logger.error("failed to retrieve block height: #{inspect(reason)}")
    {:noreply, state}
  end

  def should_sync_new_blocks?({:ok, new_height}, state = %{cursor: old_height}) when new_height > old_height do
    Logger.info("New height. Syncing blocks from #{old_height} to #{new_height}")
    {:noreply, state}
  end

  def should_sync_new_blocks?(_new_height, state) do
    {:noreply, state}
  end

  def get_current_height() do
    case Indexer.get_latest_block_number() do
      {:ok, number} ->
        {:ok,
         number
         |> Nimiqex.Policy.get_batch_from_block_number()
         |> Nimiqex.Policy.get_block_number_for_batch()}

      other ->
        other
    end
  end
end
