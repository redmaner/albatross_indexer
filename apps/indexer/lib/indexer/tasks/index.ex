defmodule Indexer.Tasks.Index do
  require Logger
  @batch_size 25

  def start(start_number, end_number, delete) do
    start_number..end_number
    |> Enum.reduce_while(:ok, &index(&1, &2, delete))
  end

  defp index(block_number, _acc, delete) do
    with :ok <- delete_block(block_number, delete),
         :ok <- index_transactions(block_number),
         :ok <- index_inherents(block_number) do
      {:cont, :ok}
    else
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  # TODO: implement block removal
  def delete_block(_number, _delete), do: :ok

  defp index_transactions(block_number) do
    case Indexer.get_transactions_by_block_number(block_number) do
      {:ok, transactions} when transactions == [] ->
        :ok

      {:ok, transactions} when is_list(transactions) ->
        transactions
        |> Stream.map(&Indexer.Core.Transaction.map_and_enrich/1)
        |> Stream.chunk_every(@batch_size)
        |> Enum.reduce_while(:ok, &store_transactions/2)
    end
  end

  defp store_transactions(transactions, _acc) do
    case Indexer.Model.Transactions.insert_many(transactions) do
      :ok -> {:cont, :ok}
      other -> {:halt, other}
    end
  end

  defp index_inherents(block_number) do
    case Indexer.get_inherents_by_block_number(block_number) do
      {:ok, inherents} when inherents == [] ->
        :ok

      {:ok, inherents} when is_list(inherents) ->
        inherents
        |> Stream.chunk_every(@batch_size)
        |> Enum.reduce_while(:ok, &store_inherents/2)
    end
  end

  defp store_inherents(inherents, _acc) do
    case Indexer.Model.Inherents.insert_many(inherents) do
      :ok -> {:cont, :ok}
      other -> {:halt, other}
    end
  end
end
