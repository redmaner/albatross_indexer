defmodule Indexer.Model.Inherents do
  @moduledoc """
  Model to interact with the `inherents` collections in MongoDB
  """
  @name :mongo
  @collection_name "inherents"

  def insert_many(inherents) do
    with {:ok, session} <- Mongo.Session.start_session(@name, :write),
         {:ok, _result} <-
           Mongo.insert_many(@name, @collection_name, inherents, session: session),
         :ok <- Mongo.Session.commit_transaction(session),
         :ok <- Mongo.Session.end_session(@name, session) do
      :ok
    end
  end
end
