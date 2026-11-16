defmodule Rephi.Repo.Migrations.AddMustChangePasswordToUsers do
  @moduledoc """
  Marks the accounts whose password was reset by an administrator
  (`Rephi.Accounts.reset_password/1`). Until the user sets a new password
  with `PUT /api/me/password`, the API only lets them read `/api/me`, change
  the password and log out.
  """
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :must_change_password, :boolean, null: false, default: false
    end
  end
end
