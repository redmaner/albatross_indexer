defmodule Indexer.Model.Inherents do
  @moduledoc """
  Model to interact with the `inherents` collections in MongoDB
  """
  @name :mongo
  @collection_name "inherents"

  @dialyzer {:no_match, insert_many: 1}

  def insert_many(inherents) do
    with {:ok, session} <- Mongo.Session.start_session(@name, :write),
         {:ok, _result} <-
           Mongo.insert_many(@name, @collection_name, inherents, session: session),
         :ok <- Mongo.Session.commit_transaction(session),
         :ok <- Mongo.Session.end_session(@name, session) do
      :ok
    end
  end

  def delete_by_block_number(block_number) do
    with {:ok, session} <- Mongo.Session.start_session(@name, :write),
         {:ok, _result} <-
           Mongo.delete_many(@name, @collection_name, %{"blockNumber" => block_number},
             session: session
           ),
         :ok <- Mongo.Session.commit_transaction(session),
         :ok <- Mongo.Session.end_session(@name, session) do
      :ok
    end
  end
end
