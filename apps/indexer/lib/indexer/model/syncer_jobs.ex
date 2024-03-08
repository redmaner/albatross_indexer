defmodule Indexer.Model.SyncerJobs do
  @name :mariadb

  import Indexer.Db

  def new_job(start_number, end_number, delete_first \\ false) do
    %{
      "start_number" => start_number,
      "end_number" => end_number,
      "status" => "NEW",
      "delete_first" => delete_first
    }
  end

  def insert_many(jobs) do
    case prepare_insert_many(
           "INSERT INTO `syncer_jobs` (`start_number`, `end_number`, `status`, `delete_first`) VALUES ",
           "(?, ?, ?, ?)",
           jobs,
           &syncer_job_to_row/1
         ) do
      {:ok, statement, args} ->
        MyXQL.query(@name, statement, args)
        |> unwrap_no_return()

      error ->
        error
    end
  end

  defp syncer_job_to_row(%{
         "end_number" => end_number,
         "status" => status,
         "start_number" => start_number,
         "delete_first" => delete_first
       }) do
    [start_number, end_number, status, delete_first]
  end

  def set_job_to_in_progress(id), do: set_job_to_status_by_id(id, "IN_PROGRESS")

  def set_job_to_completed(id), do: set_job_to_status_by_id(id, "COMPLETED")

  defp set_job_to_status_by_id(id, status) do
    MyXQL.query(@name, "UPDATE `syncer_jobs` SET `status` = ? WHERE `id` = ?", [status, id])
    |> unwrap_no_return()
  end

  def get_by_status(status, count \\ 5) do
    MyXQL.query(
      @name,
      "SELECT * FROM `syncer_jobs` WHERE status = ? ORDER BY end_number DESC LIMIT ?",
      [status, count]
    )
    |> unwrap_many_return()
  end

  def count_jobs_by_status(status \\ "NEW") do
    MyXQL.query(@name, "SELECT COUNT(*) FROM `syncer_jobs` WHERE status = ?", [status])
    |> unwrap_number()
  end
end
