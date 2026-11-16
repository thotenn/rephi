defmodule Rephi.Repo.Migrations.ReferenceAssignedByUsers do
  @moduledoc """
  `assigned_by` (who granted a role or a permission) becomes a real reference
  to `users`:

    * same type as `users.id` (`bigint`; it was an `integer`, so ids above
      2^31 could not be stored);
    * a foreign key, so it can only name an existing user, and deleting that
      user keeps the assignment and clears `assigned_by`;
    * an index, which the `ON DELETE SET NULL` needs to stay cheap.

  Existing values that point to no user are cleared first.
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

  # Values above the range of `integer` would not fit back: they make the
  # rollback fail instead of being truncated.
  def down do
    for table <- @tables do
      drop index(table, [:assigned_by])

      alter table(table) do
        modify :assigned_by, :integer, from: references(:users, on_delete: :nilify_all)
      end
    end
  end
end
