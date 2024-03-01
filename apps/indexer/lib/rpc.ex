defmodule Indexer do
  @client :rpc_client

  alias Nimiqex.RPC.Blockchain

  def call(req) do
    req
    |> Nimiqex.RPC.send(@client)
  end

  @doc """
  Returns the latest block number
  """
  def get_latest_block_number() do
    Blockchain.get_block_number()
    |> Nimiqex.RPC.send(@client)
    |> unwrap()
  end

  def get_transactions_by_block_number(batch_number) do
    batch_number
    |> Blockchain.get_transactions_by_block_number()
    |> Nimiqex.RPC.send(@client)
    |> unwrap()
  end

  def get_inherents_by_block_number(batch_number) do
    batch_number
    |> Blockchain.get_inherents_by_block_number()
    |> Nimiqex.RPC.send(@client)
  end

  def unwrap({:error, reason}), do: {:error, reason}

  def unwrap({:ok, %{"data" => data}}), do: {:ok, data}
end
