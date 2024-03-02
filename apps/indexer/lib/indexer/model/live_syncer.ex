defmodule Indexer.Model.LiveSyncer do
  @moduledoc """
  Model to interact with the `live_syncer` collection in MongoDB
  """

  @name :mongo
  @collection_name "live_syncer"
  @live_id :binary.encode_hex("live-syncer-id")

  def get_live_state() do
    @name
    |> Mongo.find(@collection_name, %{_id: @live_id})
  end

  def init_live_state(cursor) do
    with {:ok, session} <- Mongo.Session.start_session(@name, :write),
         :ok <- create_indexes(session),
         {:ok, _result} <-
           Mongo.insert_one(@name, @collection_name, %{_id: @live_id, cursor: cursor},
             session: session
           ),
         :ok <- Mongo.Session.commit_transaction(session),
         :ok <- Mongo.Session.end_session(@name, session) do
      :ok
    end
  end

  defp create_indexes(session) do
    :ok =
      Mongo.create_indexes(
        @name,
        "transactions",
        [
          [name: "transactions_idx", key: [from: -1, to: -1, blockNumber: -1]]
        ],
        session: session
      )

    :ok =
      Mongo.create_indexes(
        @name,
        "inherents",
        [
          [name: "inherents_idx", key: [blockNumber: -1]]
        ],
        session: session
      )

    :ok =
      Mongo.create_indexes(
        @name,
        "syncer_jobs",
        [
          [name: "syncer_jobs_idx", key: [end_number: -1]]
        ],
        session: session
      )
  rescue
    MatchError ->
      {:error, :failed_to_create_index}
  end

  def update_live_cursor(new_cursor) do
    with {:ok, session} <- Mongo.Session.start_session(@name, :write),
         {:ok, _result} <-
           Mongo.update_one(
             @name,
             @collection_name,
             %{_id: @live_id},
             %{"$max": %{cursor: new_cursor}},
             session: session
           ),
         :ok <- Mongo.Session.commit_transaction(session),
         :ok <- Mongo.Session.end_session(@name, session) do
      :ok
    end
  end
end
