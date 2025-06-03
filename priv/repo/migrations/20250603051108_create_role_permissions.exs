defmodule Rephi.Repo.Migrations.CreateRolePermissions do
  use Ecto.Migration

  def change do
    create table(:role_permissions) do
      add :role_id, references(:roles, on_delete: :delete_all), null: false
      add :permission_id, references(:permissions, on_delete: :delete_all), null: false
      add :assigned_by, :integer
      add :notes, :text
      
      timestamps()
    end

    create index(:role_permissions, [:role_id])
    create index(:role_permissions, [:permission_id])
    create unique_index(:role_permissions, [:role_id, :permission_id], name: :role_permissions_role_id_permission_id_index)
  end
end