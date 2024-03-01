defmodule Indexer.Model.Syncer do
  @name :mongo
  @live_id 1_709_291_470_335

  def get_live_state() do
    @name
    |> Mongo.find("syncer", %{_id: @live_id})
  end

  def init_live_state(cursor) do
    with {:ok, session} <- Mongo.Session.start_session(@name, :write),
         {:ok, _result} <-
           Mongo.insert_one(@name, "syncer", %{_id: @live_id, cursor: cursor}, session: session),
         :ok <- Mongo.Session.commit_transaction(session),
         :ok <- Mongo.Session.end_session(@name, session) do
      :ok
    end
  end

  def update_live_cursor(new_cursor) do
    with {:ok, session} <- Mongo.Session.start_session(@name, :write),
         {:ok, _result} <-
           Mongo.update_one(@name, "syncer", %{_id: @live_id}, %{"$set": %{cursor: new_cursor}},
             session: session
           ),
         :ok <- Mongo.Session.commit_transaction(session),
         :ok <- Mongo.Session.end_session(@name, session) do
      :ok
    end
  end
end
