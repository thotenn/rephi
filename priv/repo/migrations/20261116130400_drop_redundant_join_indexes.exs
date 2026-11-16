defmodule Rephi.Repo.Migrations.DropRedundantJoinIndexes do
  @moduledoc """
  Drops four single-column indexes that are the leading column of the unique
  composite index of the same table, which already serves those lookups:

    * `user_roles(user_id)` - `user_roles(user_id, role_id)`
    * `user_permissions(user_id)` - `user_permissions(user_id, permission_id)`
    * `role_permissions(role_id)` - `role_permissions(role_id, permission_id)`
    * `role_roles(parent_role_id)` - `role_roles(parent_role_id, child_role_id)`

  The indexes on the second column (`role_id`, `permission_id`,
  `child_role_id`) are still needed and stay.
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
