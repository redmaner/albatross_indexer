defmodule Indexer.Core.Transaction do
  def map_and_enrich(transaction = %{"hash" => hash}) do
    transaction
    |> Map.put("_id", hash)
    |> Map.drop(["hash"])
    |> enrich_recipient_data()
    |> enrich_sender_data()
  end

  defp enrich_recipient_data(tx = %{"recipientData" => ""}), do: tx

  defp enrich_recipient_data(tx = %{"recipientData" => recipient_data}) do
    recipient_data_decoded = recipient_data |> :binary.decode_hex()

    recipient_data_type =
      recipient_data_decoded |> binary_part(0, 1) |> extract_recipient_data_type()

    tx = tx |> Map.put("stakingContractAction", recipient_data_type)

    case recipient_data_type do
      # :CREATE_STAKER ->
      #   tx
      #   |> Map.put("delegation", parse_address_from_recipient_data(recipient_data_decoded))

      # :UPDATE_STAKER ->
      #   tx
      #   |> Map.put("newDelegation", parse_address_from_recipient_data(recipient_data_decoded))

      :ADD_STAKE ->
        tx
        |> Map.put("stakerAddress", parse_address_from_recipient_data(recipient_data_decoded))

      _other ->
        tx
    end
  end

  defp parse_address_from_recipient_data(recipient_data_decoded) do
    recipient_data_decoded
    |> binary_part(1, 20)
    |> Nimiqex.Address.to_user_friendly_address()
  end

  defp extract_recipient_data_type(<<0>>), do: :CREATE_VALIDATOR
  defp extract_recipient_data_type(<<1>>), do: :UPDATE_VALIDATOR
  defp extract_recipient_data_type(<<2>>), do: :DEACTIVATE_VALIDATOR
  defp extract_recipient_data_type(<<3>>), do: :REACTIVATE_VALIDATOR
  defp extract_recipient_data_type(<<4>>), do: :RETIRE_VALIDATOR
  defp extract_recipient_data_type(<<5>>), do: :CREATE_STAKER
  defp extract_recipient_data_type(<<6>>), do: :ADD_STAKE
  defp extract_recipient_data_type(<<7>>), do: :UPDATE_STAKER
  defp extract_recipient_data_type(<<8>>), do: :SET_ACTIVE_STAKE
  defp extract_recipient_data_type(<<9>>), do: :RETIRE_STAKE
  defp extract_recipient_data_type(_), do: :UNKNOWN

  defp enrich_sender_data(tx = %{"senderData" => ""}), do: tx

  defp enrich_sender_data(tx = %{"senderData" => sender_data, "proof" => proof}) do
    sender_data_decoded = sender_data |> :binary.decode_hex()

    sender_data_type = sender_data_decoded |> binary_part(0, 1) |> extract_sender_data_type()

    tx = tx |> Map.put("stakingContractAction", sender_data_type)

    with :REMOVE_STAKE <- sender_data_type,
         address when is_binary(address) <-
           Nimiqex.Address.extract_address_from_transaction_proof(proof) do
      tx |> Map.put("stakerAddress", address)
    else
      _other -> tx
    end
  end

  defp extract_sender_data_type(<<0>>), do: :DELETE_VALIDATOR
  defp extract_sender_data_type(<<1>>), do: :REMOVE_STAKE
  defp extract_sender_data_type(_), do: :UNKNOWN
end
