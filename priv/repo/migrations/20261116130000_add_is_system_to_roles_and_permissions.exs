defmodule Rephi.Repo.Migrations.AddIsSystemToRolesAndPermissions do
  @moduledoc """
  Marks the roles and permissions the code refers to by slug (undeletable, slug
  fixed). On an existing database, run the seeds afterwards to set the flag.
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
