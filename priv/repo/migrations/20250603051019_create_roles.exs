defmodule Rephi.Repo.Migrations.CreateRoles do
  use Ecto.Migration

  def change do
    create table(:roles) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text

      timestamps()
    end

    create unique_index(:roles, [:slug])
  end
end