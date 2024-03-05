defmodule Indexer.Db do
  def unwrap_number(error = {:error, _reason}), do: error
  def unwrap_number({:ok, %MyXQL.Result{num_rows: 0}}), do: {:error, :not_found}
  def unwrap_number({:ok, %MyXQL.Result{rows: [[number]]}}), do: {:ok, number}

  def unwrap_no_return(error = {:error, _reason}), do: error
  def unwrap_no_return({:ok, _result}), do: :ok
end
