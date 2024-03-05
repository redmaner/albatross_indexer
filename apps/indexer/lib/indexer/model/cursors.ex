defmodule Indexer.Model.Cursors do
  @moduledoc """
  Model to interact with the `cursors` table in MariaDB
  """

  import Indexer.Db

  @name :mariadb
  @live_id :binary.encode_hex("live-syncer-id")

  def get_live_cursor() do
    MyXQL.query(@name, "SELECT `cursor` FROM cursors WHERE `id` = ?;", [@live_id])
    |> unwrap_number()
  end

  def new_live_cursor(cursor) do
    MyXQL.query(@name, "INSERT INTO cursors (`id`, `cursor`) VALUES (?, ?);", [@live_id, cursor])
    |> unwrap_no_return()
  end

  def update_live_cursor(new_cursor) do
    MyXQL.query(@name, "UPDATE `cursors` SET `cursor` = ? WHERE `id` = ? AND ? > `cursor`;", [
      new_cursor,
      @live_id,
      new_cursor
    ])
    |> unwrap_no_return()
  end
end
