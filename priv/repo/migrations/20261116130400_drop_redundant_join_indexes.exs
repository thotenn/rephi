defmodule Rephi.Repo.Migrations.DropRedundantJoinIndexes do
  @moduledoc """
  Drops the single-column indexes already served by the leading column of each
  join table's unique composite index.
  """
  use Ecto.Migration

  @indexes [
    {:user_roles, :user_id},
    {:user_permissions, :user_id},
    {:role_permissions, :role_id},
    {:role_roles, :parent_role_id}
  ]

  def up do
    for {table, column} <- @indexes, do: drop_if_exists(index(table, [column]))
  end

  def down do
    for {table, column} <- @indexes, do: create_if_not_exists(index(table, [column]))
  end
end
