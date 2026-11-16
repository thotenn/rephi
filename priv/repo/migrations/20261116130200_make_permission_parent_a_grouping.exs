defmodule Rephi.Repo.Migrations.MakePermissionParentAGrouping do
  @moduledoc """
  `permissions.parent_id` only groups permissions for display: holding a
  parent permission grants nothing else.

    * deleting a parent no longer fails: its children lose the parent
      (`ON DELETE SET NULL` instead of `RESTRICT`);
    * a permission cannot be its own parent. Existing self references carry
      no meaning and are cleared.
  """
  use Ecto.Migration

  def up do
    execute "UPDATE permissions SET parent_id = NULL WHERE parent_id = id"

    alter table(:permissions) do
      modify :parent_id, references(:permissions, on_delete: :nilify_all),
        from: references(:permissions, on_delete: :restrict)
    end

    create constraint(:permissions, :permissions_not_own_parent, check: "parent_id <> id")
  end

  def down do
    drop constraint(:permissions, :permissions_not_own_parent)

    alter table(:permissions) do
      modify :parent_id, references(:permissions, on_delete: :restrict),
        from: references(:permissions, on_delete: :nilify_all)
    end
  end
end
