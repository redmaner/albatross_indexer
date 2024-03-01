defmodule Indexer.Processes.LiveSyncer do
  require Logger
  use GenServer

  @check_height_frequency :timer.seconds(30)

  def init(_) do
    state = %{cursor: 0, tasks: %{}, pending_height: 0}
    {:ok, state, {:continue, :check_status}}
  end

  def new_task_state(start_number, end_number) do
    %{start_number: start_number, end_number: end_number}
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: {:global, __MODULE__})
  end

  def handle_continue(:check_status, state) do
    case Indexer.Model.LiveSyncer.get_live_state() do
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
         :ok <- create_history_syncer_jobs(number),
         :ok <- Indexer.Model.LiveSyncer.init_live_state(number) do
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
      end_number = min(current_height, start_number + 10000)
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

  def handle_info({ref, :ok}, state = %{tasks: tasks}) do
    # We don't care about the DOWN message now, so let's demonitor and flush it
    Process.demonitor(ref, [:flush])

    {task, tasks} = tasks |> Map.pop(ref, :not_found)

    case task do
      :not_found ->
        Logger.warning("Unknown task reference received")

      %{start_number: start_number, end_number: end_number} ->
        case Indexer.Model.LiveSyncer.update_live_cursor(end_number) do
          :ok ->
            Logger.info("Indexing from #{start_number} to #{end_number} complete")

          {:error, reason} ->
            Logger.error("Error when updating cursor after index: #{reason}")
        end
    end

    # Do something with the result and then return
    {:noreply, %{state | tasks: tasks}}
  end

  # The task failed
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Log and possibly restart the task...
    Logger.warning("One task was down: HANDLE THIS")
    {:noreply, state}
  end

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

    %Task{ref: ref} =
      Task.Supervisor.async(
        {:via, PartitionSupervisor, {Indexer.TaskSupervisors, self()}},
        Indexer.Tasks.Index,
        :start,
        [old_height + 1, new_height, false]
      )

    new_tasks = tasks |> Map.put(ref, new_task_state(old_height, new_height))

    Process.send_after(self(), :check_height, @check_height_frequency)

    {:noreply, %{state | tasks: new_tasks, cursor: new_height}}
  end

  def should_sync_new_blocks?(_new_height, state) do
    Process.send_after(self(), :check_height, @check_height_frequency)
    Logger.info("Chain not progressed for indexing, checking in 60 secs")
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
