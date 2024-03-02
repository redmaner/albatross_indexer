defmodule Indexer.Model.SyncerJobs do
  @name :mongo
  @collection_name "syncer_jobs"

  @dialyzer {:no_match, insert_many: 1}

  def new_job(start_number, end_number, delete_first \\ false) do
    %{
      "start_number" => start_number,
      "end_number" => end_number,
      "status" => "NEW",
      "delete_first" => delete_first
    }
  end

  def insert_many(jobs) do
    with {:ok, session} <- Mongo.Session.start_session(@name, :write),
         {:ok, _result} <-
           Mongo.insert_many(@name, @collection_name, jobs, session: session),
         :ok <- Mongo.Session.commit_transaction(session),
         :ok <- Mongo.Session.end_session(@name, session) do
      :ok
    end
  end

  def set_job_to_in_progress(id), do: set_job_to_status_by_id(id, "IN_PROGRESS")

  def set_job_to_completed(id), do: set_job_to_status_by_id(id, "COMPLETED")

  defp set_job_to_status_by_id(id, status) do
    with {:ok, session} <- Mongo.Session.start_session(@name, :write),
         {:ok, _result} <-
           Mongo.update_one(
             @name,
             @collection_name,
             %{_id: id},
             %{"$set": %{status: status}},
             session: session
           ),
         :ok <- Mongo.Session.commit_transaction(session),
         :ok <- Mongo.Session.end_session(@name, session) do
      :ok
    end
  end

  def get_by_status(status, count \\ 5) do
    @name
    |> Mongo.find(@collection_name, %{status: status}, limit: count, sort: %{"end_number" => -1})
  end

  def count_jobs_by_status(status \\ "NEW") do
    @name
    |> Mongo.count_documents(@collection_name, %{status: status})
  end
end
