defmodule Rephi.Repo.Migrations.CreateRoleRoles do
  use Ecto.Migration

  def change do
    create table(:role_roles) do
      add :parent_role_id, references(:roles, on_delete: :delete_all), null: false
      add :child_role_id, references(:roles, on_delete: :delete_all), null: false
      
      timestamps()
    end

    create index(:role_roles, [:parent_role_id])
    create index(:role_roles, [:child_role_id])
    create unique_index(:role_roles, [:parent_role_id, :child_role_id], name: :role_roles_parent_role_id_child_role_id_index)
  end
end