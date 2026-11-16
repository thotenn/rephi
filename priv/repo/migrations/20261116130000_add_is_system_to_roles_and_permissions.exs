defmodule Rephi.Repo.Migrations.AddIsSystemToRolesAndPermissions do
  @moduledoc """
  Marks the roles and permissions the application itself depends on.

  A system role or permission cannot be deleted and its slug cannot change
  (`Rephi.Authorization`), because plugs and the code refer to it by slug.
  `Rephi.Seeds` sets the flag on the records it creates, and on the existing
  ones with the same slug: after running this migration on an existing
  database, run the seeds once (they are idempotent).
  """
  use Ecto.Migration

  def change do
    alter table(:roles) do
      add :is_system, :boolean, null: false, default: false
    end

    alter table(:permissions) do
      add :is_system, :boolean, null: false, default: false
    end
  end
end
