defmodule Indexer.Model.Transactions do
  @moduledoc """
  Model to interact with the `transactions` collections in MongoDB
  """

  @name :mongo
  @collection_name "transactions"

  def insert_many(transactions) do
    with {:ok, session} <- Mongo.Session.start_session(@name, :write),
         {:ok, _result} <-
           Mongo.insert_many(@name, @collection_name, transactions, session: session),
         :ok <- Mongo.Session.commit_transaction(session),
         :ok <- Mongo.Session.end_session(@name, session) do
      :ok
    end
  end
end
