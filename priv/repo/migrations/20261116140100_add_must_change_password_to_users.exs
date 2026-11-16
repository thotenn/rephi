defmodule Rephi.Repo.Migrations.AddMustChangePasswordToUsers do
  @moduledoc "Flags accounts whose password an administrator reset."
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :must_change_password, :boolean, null: false, default: false
    end
  end
end
