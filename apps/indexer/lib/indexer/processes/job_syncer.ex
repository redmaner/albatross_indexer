defmodule Indexer.Processes.JobSyncer do
  require Logger
  use GenServer

  @max_concurrent_jobs 8
  @load_job_frequency :timer.seconds(120)

  def init(_) do
    state = %{tasks: %{}, load_job_timer: nil}
    {:ok, state, {:continue, :continue_in_progress}}
  end

  def new_task_state(start_number, end_number, job_id) do
    %{start_number: start_number, end_number: end_number, job_id: job_id}
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: {:global, __MODULE__})
  end

  def handle_continue(:continue_in_progress, state = %{tasks: tasks}) do
    case Indexer.Model.SyncerJobs.get_by_status("IN_PROGRESS", 0) do
      {:error, reason} ->
        Logger.error("failed to get syncer jobs IN_PROGRESS: #{inspect(reason)}")
        {:shutdown, :error}

      %{docs: docs} when docs == [] ->
        Logger.info("no in progress syncer jobs found")
        Process.send_after(self(), :load_jobs, :timer.seconds(20))

        {:noreply, state}

      %{docs: docs} when is_list(docs) ->
        Logger.info("Starting #{length(docs)} jobs with status IN_PROGRESS")

        timer = Process.send_after(self(), :load_jobs, @load_job_frequency)

        case start_jobs(tasks, docs) do
          tasks when is_map(tasks) ->
            {:noreply, %{state | tasks: tasks, load_job_timer: timer}}

          {:error, reason} ->
            Logger.error("Failed to start new job: #{inspect(reason)}")
            {:noreply, %{state | load_job_timer: timer}}
        end
    end
  end

  def handle_info(:load_jobs, state = %{tasks: tasks})
      when map_size(tasks) >= @max_concurrent_jobs do
    timer = Process.send_after(self(), :load_jobs, @load_job_frequency)
    {:noreply, %{state | load_job_timer: timer}}
  end

  def handle_info(:load_jobs, state = %{tasks: tasks}) do
    remaining_jobs = max(@max_concurrent_jobs - map_size(tasks), 1)

    case Indexer.Model.SyncerJobs.get_by_status("NEW", remaining_jobs) do
      {:error, reason} ->
        Logger.error("failed to get syncer jobs NEW: #{inspect(reason)}")
        {:shutdown, :error}

      %{docs: docs} when docs == [] ->
        timer = Process.send_after(self(), :load_jobs, @load_job_frequency)
        {:noreply, %{state | load_job_timer: timer}}

      %{docs: docs} when is_list(docs) ->
        Logger.info("Starting #{length(docs)} jobs with status NEW")
        timer = Process.send_after(self(), :load_jobs, @load_job_frequency)

        case start_jobs(tasks, docs) do
          tasks when is_map(tasks) ->
            {:noreply, %{state | tasks: tasks, load_job_timer: timer}}

          {:error, reason} ->
            Logger.error("Failed to start new job: #{inspect(reason)}")
            {:noreply, %{state | load_job_timer: timer}}
        end
    end
  end

  def handle_info({ref, :ok}, state = %{tasks: tasks, load_job_timer: timer}) do
    if timer do
      Process.cancel_timer(timer)
    end

    # We don't care about the DOWN message now, so let's demonitor and flush it
    Process.demonitor(ref, [:flush])

    {task, tasks} = tasks |> Map.pop(ref, :not_found)

    case task do
      :not_found ->
        Logger.warning("Unknown task reference received")

      %{start_number: start_number, end_number: end_number, job_id: job_id} ->
        case Indexer.Model.SyncerJobs.set_job_to_completed(job_id) do
          :ok ->
            Logger.info("Indexing job from #{start_number} to #{end_number} complete")

          {:error, reason} ->
            Logger.error("Error when updating cursor after index: #{reason}")
        end
    end

    Process.send(self(), :load_jobs, [])

    # Do something with the result and then return
    {:noreply, %{state | tasks: tasks}}
  end

  # The task failed
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Log and possibly restart the task...
    Logger.warning("One task was down: HANDLE THIS")
    {:noreply, state}
  end

  def start_jobs(tasks, jobs) do
    jobs
    |> Enum.reduce_while(tasks, &start_job(&1, &2))
  end

  def start_job(
        %{
          "_id" => job_id,
          "end_number" => end_number,
          "start_number" => start_number,
          "status" => status,
          "delete_first" => delete_first
        },
        tasks
      ) do
    do_delete = if status == "IN_PROGRESS", do: true, else: delete_first

    %{ref: ref} =
      Task.Supervisor.async(
        {:via, PartitionSupervisor, {Indexer.TaskSupervisors, self()}},
        Indexer.Tasks.Index,
        :start,
        [start_number, end_number, do_delete]
      )

    case Indexer.Model.SyncerJobs.set_job_to_in_progress(job_id) do
      :ok ->
        Logger.info(
          "Started new index job with status #{status}. Indexing from block #{start_number} to #{end_number}"
        )

        {:cont,
         tasks
         |> Map.put(ref, new_task_state(start_number, end_number, job_id))}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end
end
