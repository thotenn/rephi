defmodule Rephi.Repo.Migrations.CreatePermissions do
  use Ecto.Migration

  def change do
    create table(:permissions) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :parent_id, references(:permissions, on_delete: :restrict)

      timestamps()
    end

    create unique_index(:permissions, [:slug])
    create index(:permissions, [:parent_id])
  end
end