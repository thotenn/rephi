defmodule Rephi.Repo.Migrations.HardenUsersEmailAndPassword do
  @moduledoc """
  Makes the `users` table enforce what the application already assumes:

    * emails are stored trimmed and lowercased, and are unique regardless of
      case (`Admin@example.com` and `admin@example.com` are the same account);
    * `email` and `hashed_password` can never be `NULL`.

  The migration refuses to run, without changing anything, when the existing
  data cannot satisfy those rules. Resolve the rows it lists and run it again.
  """
  use Ecto.Migration

  def up do
    execute(&ensure_no_incomplete_users!/0)
    execute(&ensure_no_case_duplicates!/0)

    execute "UPDATE users SET email = lower(btrim(email)) WHERE email <> lower(btrim(email))"

    drop unique_index(:users, [:email])
    # Same name as the index it replaces, so `unique_constraint(:email)` in
    # the changeset keeps working.
    create unique_index(:users, ["lower(email)"], name: :users_email_index)

    alter table(:users) do
      modify :email, :string, null: false, from: {:string, null: true}
      modify :hashed_password, :string, null: false, from: {:string, null: true}
    end
  end

  def down do
    alter table(:users) do
      modify :email, :string, null: true, from: {:string, null: false}
      modify :hashed_password, :string, null: true, from: {:string, null: false}
    end

    drop unique_index(:users, ["lower(email)"], name: :users_email_index)
    create unique_index(:users, [:email])
  end

  defp ensure_no_incomplete_users! do
    %{rows: rows} =
      repo().query!(
        "SELECT id FROM users WHERE email IS NULL OR hashed_password IS NULL ORDER BY id"
      )

    if rows != [] do
      raise """
      cannot make users.email and users.hashed_password NOT NULL: \
      #{length(rows)} user(s) have no email or no password hash \
      (ids: #{rows |> List.flatten() |> Enum.join(", ")}). \
      Fix or delete those rows and run the migration again.
      """
    end
  end

  defp ensure_no_case_duplicates! do
    %{rows: rows} =
      repo().query!("""
      SELECT lower(btrim(email)), array_agg(id ORDER BY id)
      FROM users
      GROUP BY lower(btrim(email))
      HAVING count(*) > 1
      ORDER BY 1
      """)

    if rows != [] do
      duplicates =
        Enum.map_join(rows, "\n", fn [email, ids] ->
          "  #{email} (ids: #{Enum.join(ids, ", ")})"
        end)

      raise """
      cannot make users.email unique regardless of case: these emails belong \
      to more than one user once trimmed and lowercased:

      #{duplicates}

      Merge or delete the duplicates and run the migration again.
      """
    end
  end
end
