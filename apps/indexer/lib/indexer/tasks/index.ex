defmodule Indexer.Tasks.Index do
  @moduledoc """
  Module that is meant to be run as a Task using a Task.Supervisor
  This module is responsible for indexing transactions and inherents for a range of blocks
  """

  require Logger
  @batch_size 100

  @dialyzer {:no_match, store_inherents: 2}

  @doc """
  start indexing a range of blocks
  * start_number => start of the block range
  * end_number => end of the blcok range
  * delete => remove resources for the block before inserting new resources
  """
  @spec start(integer(), integer(), boolean() | integer()) :: :ok | {:error, term()}
  def start(start_number, end_number, 1) do
    start(start_number, end_number, true)
  end

  def start(start_number, end_number, delete) when is_integer(delete) do
    start(start_number, end_number, false)
  end

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

  def delete_block(_number, false), do: :ok

  def delete_block(block_number, true) do
    with :ok <- Indexer.Model.Transactions.delete_by_block_number(block_number),
         :ok <- Indexer.Model.Inherents.delete_by_block_number(block_number) do
      :ok
    end
  end

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
