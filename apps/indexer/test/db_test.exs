defmodule DbTest do
  use ExUnit.Case

  def extract_test_value(value), do: value

  test "prepare_insert_many" do
    {:ok, statement, args} =
      Indexer.Db.prepare_insert_many(
        "INSERT INTO test VALUES ",
        "(?, ?)",
        [[1, 2], [3, 4]],
        &extract_test_value/1
      )

    assert statement == "INSERT INTO test VALUES (?, ?),(?, ?)"
    assert args == [3, 4, 1, 2]
  end
end
