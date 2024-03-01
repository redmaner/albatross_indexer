defmodule Indexer.Tasks.Index do
  @batch_size 25

  def start(start_number, end_number, delete) do
    start_number..end_number
    |> Enum.reduce_while(:ok, &index(&1, &2, delete))
  end

  defp index(block_number, _acc, delete) do
    with :ok <- delete_block(block_number, delete),
         :ok <- index_transactions(block_number) do
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
end
