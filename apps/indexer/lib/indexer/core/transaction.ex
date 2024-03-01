defmodule Indexer.Core.Transaction do
  def map_and_enrich(transaction) do
    {hash, transaction} = Map.pop(transaction, "hash")

    transaction
    |> Map.put("_id", hash)
  end
end
