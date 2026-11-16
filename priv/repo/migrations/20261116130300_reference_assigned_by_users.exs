defmodule Rephi.Repo.Migrations.ReferenceAssignedByUsers do
  @moduledoc """
  Makes `assigned_by` a `bigint` foreign key to `users` (`ON DELETE SET NULL`,
  indexed). Values that point to no user are cleared first.
  """
  use Ecto.Migration

  @tables [:user_roles, :user_permissions, :role_permissions]

  def up do
    for table <- @tables do
      execute """
      UPDATE #{table} SET assigned_by = NULL
      WHERE assigned_by IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM users WHERE users.id = #{table}.assigned_by)
      """

      alter table(table) do
        modify :assigned_by, references(:users, on_delete: :nilify_all), from: :integer
      end

      create index(table, [:assigned_by])
    end
  end

  # Ids beyond the `integer` range make the rollback fail instead of being truncated.
  def down do
    for table <- @tables do
      drop index(table, [:assigned_by])

      alter table(table) do
        modify :assigned_by, :integer, from: references(:users, on_delete: :nilify_all)
      end
    end
  end
end
