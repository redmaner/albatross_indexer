defmodule Indexer.Model.Transactions do
  @moduledoc """
  Model to interact with the `transactions` collections in MongoDB
  """
  import Indexer.Db
  @name :mariadb

  @insert_statement "INSERT INTO `transactions` (`hash`, `from`, `fromType`, `to`, `toType`, `blockNumber`, `value`, `fee`, `executionResult`, `recipientData`, `senderData`, `proof`, `confirmations`, `validityStartHeight`, `timestamp`, `flags`, `networkId`) VALUES "
  @insert_values "(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"

  def insert_many(transactions) do
    case prepare_insert_many(
           @insert_statement,
           @insert_values,
           transactions,
           &parse_transaction_to_row/1
         ) do
      {:ok, statement, args} ->
        MyXQL.query(@name, statement, args)
        |> unwrap_no_return()

      error ->
        error
    end
  end

  defp parse_transaction_to_row(%{
        "hash" => hash,
        "from" => from,
        "fromType" => from_type,
        "to" => to,
        "toType" => to_type,
        "blockNumber" => block_number,
        "value" => value,
        "fee" => fee,
        "executionResult" => execution_result,
        "recipientData" => recipient_data,
        "senderData" => sender_data,
        "proof" => proof,
        "confirmations" => confirmations,
        "validityStartHeight" => validity_start_height,
        "timestamp" => timestamp,
        "flags" => flags,
        "networkId" => network_id
      }) do
    [
      hash,
      from,
      from_type,
      to,
      to_type,
      block_number,
      value,
      fee,
      execution_result,
      recipient_data,
      sender_data,
      proof,
      confirmations,
      validity_start_height,
      timestamp,
      flags,
      network_id
    ]
  end

  def delete_by_block_number(block_number) do
    MyXQL.query(@name, "DELETE FROM `transactions` WHERE blockNumber = ?", [block_number])
    |> unwrap_no_return()
  end

  def get_latest_block_number() do
    MyXQL.query(
      @name,
      "SELECT `blockNumber` from `transactions` ORDER BY blockNumber DESC LIMIT 1"
    )
    |> unwrap_number()
  end
end
