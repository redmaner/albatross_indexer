defmodule Indexer.Model.Syncer do
  @name :mongo

  def get_live_state() do
    @name
    |> Mongo.find("syncer", %{name: "live-syncer-state"})
  end

  def init_state() do
    with {:ok, session} <- Mongo.Session.start_session(@name, :write),
         {:ok, _result} <-
           Mongo.insert_one(@name, "syncer", %{name: "status"}, session: session),
         :ok <- Mongo.Session.commit_transaction(session),
         :ok <- Mongo.Session.end_session(@name, session) do
      :ok
    end
  end
end
