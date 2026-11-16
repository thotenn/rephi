defmodule Rephi.Repo.Migrations.AddTokenVersionToUsers do
  @moduledoc """
  Adds the counter that lets a user's tokens be revoked.

  Every JWT carries the `token_version` its user had when it was issued and is
  only accepted while the two still match. Incrementing the column (password
  change, logout) invalidates every token issued before.
  """
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :token_version, :integer, null: false, default: 0
    end
  end
end
