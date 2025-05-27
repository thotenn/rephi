# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Rephi.Repo.insert!(%Rephi.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Rephi.Repo
alias Rephi.Accounts.User

# Create first user
admin_attrs = %{
  email: "admin@admin.com",
  password: "password123!!"
}

case Repo.get_by(User, email: admin_attrs.email) do
  nil ->
    %User{}
    |> User.changeset(admin_attrs)
    |> Repo.insert!()
    IO.puts("User created: #{admin_attrs.email}")

  _user ->
    IO.puts("User already exists: #{admin_attrs.email}")
end
