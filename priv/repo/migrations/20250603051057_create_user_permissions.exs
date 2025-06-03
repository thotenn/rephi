defmodule Rephi.Repo.Migrations.CreateUserPermissions do
  use Ecto.Migration

  def change do
    create table(:user_permissions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :permission_id, references(:permissions, on_delete: :delete_all), null: false
      add :assigned_by, :integer
      add :notes, :text
      
      timestamps()
    end

    create index(:user_permissions, [:user_id])
    create index(:user_permissions, [:permission_id])
    create unique_index(:user_permissions, [:user_id, :permission_id], name: :user_permissions_user_id_permission_id_index)
  end
end