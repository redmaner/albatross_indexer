defmodule Indexer do
  @client :rpc_client

  alias Nimiqex.Blockchain

  def call(req) do
    req
    |> Nimiqex.send(@client)
  end

  @doc """
  Returns the latest block number
  """
  def get_latest_block_number() do
    Blockchain.get_block_number()
    |> Nimiqex.send(@client)
  end

  @doc """
  Returns the latest epoch number
  """
  def get_latest_epoch_number() do
    Blockchain.get_epoch_number()
    |> Nimiqex.send(@client)
  end

  @doc """
  Returns the latest batch number
  """
  def get_latest_batch_number() do
    Blockchain.get_batch_number()
    |> Nimiqex.send(@client)
  end

  @doc """
  Get block by number
  """
  def get_block_by_number(block_number) do
    block_number
    |> Blockchain.get_block_by_number(false)
    |> Nimiqex.send(@client)
  end

  @doc """
  Get block by hash
  """
  def get_block_by_hash(block_hash) do
    block_hash
    |> Blockchain.get_block_by_hash(false)
    |> Nimiqex.send(@client)
  end

  @doc """
  Get latest block
  """
  def get_latest_block do
    Blockchain.get_latest_block(false)
    |> Nimiqex.send(@client)
  end

  def get_inherents_by_batch_number(batch_number) do
    batch_number
    |> Blockchain.get_inherents_by_batch_number()
    |> Nimiqex.send(@client)
  end

  def get_inherents_by_block_number(batch_number) do
    batch_number
    |> Blockchain.get_inherents_by_block_number()
    |> Nimiqex.send(@client)
  end

  @doc """
  Retrieve staking contract list
  """
  def get_active_validators() do
    Blockchain.get_active_validators()
    |> Nimiqex.send(@client)
  end

  @doc """
  Get validator
  """
  def get_validator(address) do
    address
    |> Blockchain.get_validator_by_address()
    |> Nimiqex.send(@client)
  end

  @doc """
  Get stakers by validator
  """
  def get_stakers_by_validator_address(address) do
    address
    |> Blockchain.get_stakers_by_validator_address()
    |> Nimiqex.send(@client)
  end
end
