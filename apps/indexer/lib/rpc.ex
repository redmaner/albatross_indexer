defmodule Indexer do
  alias Nimiqex.RPC.Blockchain

  @doc """
  Returns the latest block number
  """
  def get_latest_block_number() do
    Blockchain.get_block_number()
    |> Nimiqex.RPC.send({:via, PartitionSupervisor, {Indexer.RPCPartition, self()}})
    |> unwrap()
  end

  def get_transactions_by_block_number(batch_number) do
    batch_number
    |> Blockchain.get_transactions_by_block_number()
    |> Nimiqex.RPC.send({:via, PartitionSupervisor, {Indexer.RPCPartition, batch_number}})
    |> unwrap()
  end

  def get_inherents_by_block_number(batch_number) do
    batch_number
    |> Blockchain.get_inherents_by_block_number()
    |> Nimiqex.RPC.send({:via, PartitionSupervisor, {Indexer.RPCPartition, batch_number}})
    |> unwrap()
  end

  def unwrap({:error, reason}), do: {:error, reason}

  def unwrap({:ok, %{"data" => data}}), do: {:ok, data}
end
