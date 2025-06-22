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
alias Rephi.Authorization

# Run authorization seeds first (creates roles and permissions)
Code.eval_file("priv/repo/authorization_seeds.exs")

# Create first user
admin_attrs = %{
  email: "admin@admin.com",
  password: "password123!!"
}

admin_user =
  case Repo.get_by(User, email: admin_attrs.email) do
    nil ->
      user =
        %User{}
        |> User.changeset(admin_attrs)
        |> Repo.insert!()

      IO.puts("User created: #{admin_attrs.email}")
      user

    user ->
      IO.puts("User already exists: #{admin_attrs.email}")
      user
  end

# Assign admin role to the admin user
admin_role = Authorization.get_role_by_slug("admin")

if admin_role do
  case Authorization.assign_role_to_user(admin_user, admin_role) do
    {:ok, _} -> IO.puts("Assigned admin role to #{admin_user.email}")
    {:error, _} -> IO.puts("Admin role already assigned to #{admin_user.email}")
  end
end
