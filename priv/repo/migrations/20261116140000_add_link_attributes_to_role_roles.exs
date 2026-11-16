defmodule Rephi.Repo.Migrations.AddLinkAttributesToRoleRoles do
  @moduledoc """
  The links of the role hierarchy get what the other grants already have:

    * `assigned_by` - who linked the parent (a reference to `users`, cleared
      when that user is deleted) and `notes`;
    * `is_system` - the link is part of the seeded hierarchy
      (`Rephi.Seeds`): it cannot be removed, like a system role cannot be
      deleted. Seeding marks the links it makes.

  Existing links between two system roles are marked as system links here,
  so a database that is not seeded again after the upgrade is already
  protected.
  """
  use Ecto.Migration

  def up do
    alter table(:role_roles) do
      add :assigned_by, references(:users, on_delete: :nilify_all)
      add :notes, :text
      add :is_system, :boolean, null: false, default: false
    end

    create index(:role_roles, [:assigned_by])

    execute """
    UPDATE role_roles SET is_system = true
    FROM roles AS child, roles AS parent
    WHERE child.id = role_roles.child_role_id
      AND parent.id = role_roles.parent_role_id
      AND child.is_system AND parent.is_system
    """
  end

  def down do
    drop index(:role_roles, [:assigned_by])

    alter table(:role_roles) do
      remove :is_system
      remove :notes
      remove :assigned_by
    end
  end
end
