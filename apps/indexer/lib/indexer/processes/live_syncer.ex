defmodule Indexer.Processes.LiveSyncer do
  @moduledoc """
  LiveSyncer is responsible for keeping track of the tip of the blockchain. When the tip
  of the blockchain is progressed a new Indexer.Task.Index is run as Task under a
  Task.Supervisor
  """
  require Logger
  use GenServer

  @check_height_frequency :timer.seconds(30)
  @history_syncer_job_size 1000

  @dialyzer {:no_match, handle_continue: 2}

  def init(_) do
    state = %{cursor: 0, tasks: %{}}
    {:ok, state, {:continue, :check_status}}
  end

  def new_task_state(start_number, end_number) do
    %{start_number: start_number, end_number: end_number}
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: {:global, __MODULE__})
  end

  def handle_continue(:check_status, state) do
    case Indexer.Model.Cursors.get_live_cursor() do
      {:error, :not_found} ->
        {:noreply, state, {:continue, :init_state}}

      {:ok, cursor} ->
        Logger.info("Got a cursor: #{inspect(cursor)}")
        Process.send(self(), :check_height, [])

        {:noreply, %{state | cursor: cursor}}

      {:error, reason} ->
        Logger.error("Error when retrieving state: #{inspect(reason)}")
        {:shutdown, reason}
    end
  end

  # init_state is ran on the very first time when no live_syncer state
  # is stored in MongoDB. When this is the case a new cursor is created
  # and syncer jobs are created from genesis to the curren cursor.
  def handle_continue(:init_state, state) do
    with {:ok, number} <- get_current_height(),
         :ok <- create_history_syncer_jobs(number),
         :ok <- Indexer.Model.Cursors.new_live_cursor(number) do
      Logger.info("Initialised new state")

      Process.send(self(), :check_height, [])

      {:noreply, %{state | cursor: number}}
    else
      {:error, reason} ->
        Logger.error("encountered error initializing state: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  def create_history_syncer_jobs(current_height) do
    genesis_height = Nimiqex.Policy.genesis_block_number()

    Stream.iterate(0, &(&1 + 1))
    |> Enum.reduce_while({[], genesis_height}, fn _, {jobs, start_number} ->
      end_number = min(current_height, start_number + @history_syncer_job_size)
      continue = end_number < current_height

      jobs = [Indexer.Model.SyncerJobs.new_job(start_number + 1, end_number) | jobs]

      if continue do
        {:cont, {jobs, end_number}}
      else
        {:halt, {jobs, end_number}}
      end
    end)
    |> store_syncer_jobs()
  end

  def store_syncer_jobs({jobs, _}) do
    Indexer.Model.SyncerJobs.insert_many(jobs)
  end

  # Ran when an index task was completed succesfully
  def handle_info({ref, :ok}, state = %{tasks: tasks}) do
    Process.demonitor(ref, [:flush])

    {task, tasks} = tasks |> Map.pop(ref, :not_found)

    case task do
      :not_found ->
        Logger.warning("Unknown task reference received")

      %{start_number: start_number, end_number: end_number} ->
        case Indexer.Model.Cursors.update_live_cursor(end_number) do
          :ok ->
            Logger.info("Indexing from #{start_number} to #{end_number} complete")

          {:error, reason} ->
            Logger.error("Error when updating cursor after index: #{reason}")
        end
    end

    {:noreply, %{state | tasks: tasks}}
  end

  # TODO: implement this
  # Ran when a task is failed
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    Logger.warning("One task was down: HANDLE THIS")
    {:noreply, state}
  end

  # This is ran periodically to check for a new height.
  # When the chain is progressed we start a new index task.
  def handle_info(:check_height, state) do
    get_current_height()
    |> should_sync_new_blocks?(state)
  end

  def should_sync_new_blocks?({:error, reason}, state) do
    Logger.error("failed to retrieve block height: #{inspect(reason)}")
    Process.send_after(self(), :check_height, @check_height_frequency)

    {:noreply, state}
  end

  def should_sync_new_blocks?({:ok, new_height}, state = %{cursor: old_height, tasks: tasks})
      when new_height > old_height do
    Logger.info("New height. Syncing blocks from #{old_height} to #{new_height}")

    should_delete =
      case Indexer.Model.Transactions.get_latest_block_number() do
        {:ok, indexed_number} -> indexed_number > old_height
        _other -> true
      end

    old_height = old_height + 1

    %Task{ref: ref} =
      Task.Supervisor.async(
        {:via, PartitionSupervisor, {Indexer.TaskSupervisors, self()}},
        Indexer.Tasks.Index,
        :start,
        [old_height, new_height, should_delete]
      )

    new_tasks = tasks |> Map.put(ref, new_task_state(old_height, new_height))

    Process.send_after(self(), :check_height, @check_height_frequency)

    {:noreply, %{state | tasks: new_tasks, cursor: new_height}}
  end

  def should_sync_new_blocks?(_new_height, state) do
    Process.send_after(self(), :check_height, @check_height_frequency)
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
