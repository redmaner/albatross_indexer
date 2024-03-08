defmodule Indexer.Db do
  def prepare_insert_many(_statement, _value_statement, values, _value_extractor)
      when values == [] do
    {:error, :no_values}
  end

  def prepare_insert_many(statement, value_statement, values, value_extractor)
      when is_binary(statement) do
    prepare_insert_many({statement, []}, value_statement, values, value_extractor)
  end

  def prepare_insert_many({statement, args}, value_statement, [value | []], value_extractor) do
    statement = statement <> value_statement
    arg = value_extractor.(value)
    args = List.flatten([arg | args])

    {:ok, statement, args}
  end

  def prepare_insert_many({statement, args}, value_statement, [value | head], value_extractor) do
    statement = statement <> value_statement <> ","
    arg = value_extractor.(value)
    prepare_insert_many({statement, [arg | args]}, value_statement, head, value_extractor)
  end

  def unwrap_number(error = {:error, _reason}), do: error
  def unwrap_number({:ok, %MyXQL.Result{num_rows: 0}}), do: {:error, :not_found}
  def unwrap_number({:ok, %MyXQL.Result{rows: [[number]]}}), do: {:ok, number}

  def unwrap_no_return(error = {:error, _reason}), do: error
  def unwrap_no_return({:ok, _result}), do: :ok

  def unwrap_many_return(error = {:error, _reason}), do: error
  def unwrap_many_return({:ok, %MyXQL.Result{num_rows: 0}}), do: {:ok, []}

  def unwrap_many_return({:ok, %MyXQL.Result{rows: rows, columns: cols}}) do
    {:ok,
     rows
     |> Stream.map(&Enum.zip(cols, &1))
     |> Enum.map(&Map.new/1)}
  end
end
