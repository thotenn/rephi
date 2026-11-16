defmodule Rephi.Repo.Migrations.AddTokenVersionToUsers do
  @moduledoc """
  Adds `users.token_version`: a JWT is accepted only while its version matches,
  so incrementing it revokes every earlier token.
  """
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :token_version, :integer, null: false, default: 0
    end
  end
end
