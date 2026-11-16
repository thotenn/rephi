defmodule Rephi.Seeds do
  @moduledoc """
  The data every installation starts with: the default roles and permissions,
  and the first administrator.

  `priv/repo/seeds.exs` calls `run/1` (so does `mix ecto.setup`). It lives in
  `lib/` so a running release can seed too:

      bin/rephi rpc "Rephi.Seeds.run() |> IO.inspect()"

  ## Guarantees

    * **Idempotent** - running it again changes nothing. A missing role,
      permission or assignment is added back; what already exists is left
      untouched (a role renamed by hand keeps its new name).
    * **All or nothing** - everything happens in one transaction.
    * **No hardcoded administrator outside development** - see below.

  Roles, permissions and the grants between them are plain data in this
  module (`roles/0`, `permissions/0`): adding a permission is one line, and
  seeding again adds it to an existing database.

  Every seeded role and permission is marked `is_system` (it cannot be
  deleted nor have its slug changed), including rows that already existed
  with the same slug: that is the one thing seeding changes on existing
  rows.

  ## Grants the seed no longer makes

  Seeding never revokes anything. When the seed stops granting a permission
  to a role (as `users:view` stopped being granted to `user`), an existing
  database keeps the old grant. `run/1` reports them as `:stale_grants`
  (`[{role_slug, permission_slug}]`, only between seeded roles and seeded
  permissions) and `priv/repo/seeds.exs` prints how to revoke them. Review
  them: a grant you made on purpose looks the same.

  ## The administrator

  `ADMIN_EMAIL` and `ADMIN_PASSWORD` name the administrator (a user with the
  `admin` role). If the user already exists it only gets the role; its
  password is never changed.

  Without those variables the outcome depends on
  `config :rephi, Rephi.Seeds, admin: mode`:

    * `:required` (default, production) - `run/1` fails and seeds nothing;
    * `:default` (development) - the well-known development account
      `admin@admin.com` / `password123!!` is used, and the result says so
      (`seeds.exs` prints a warning);
    * `:optional` (test) - no administrator is created.
  """

  import Ecto.Query, warn: false

  alias Rephi.{Accounts, Repo}
  alias Rephi.Accounts.User
  alias Rephi.Authorization.{Permission, Role}

  @default_admin %{email: "admin@admin.com", password: "password123!!"}

  @roles [
    %{slug: "admin", name: "Administrator", description: "Full system access"},
    %{slug: "manager", name: "Manager", description: "Management level access"},
    %{slug: "user", name: "User", description: "Basic user access"}
  ]

  # {child, parent}: the child role inherits every permission of the parent.
  @role_hierarchy [{"admin", "manager"}, {"manager", "user"}]

  # {slug, name, description, roles granted it directly}. Admin gets every
  # permission directly, on top of what it inherits. The `user` role, which
  # every new account gets (`Rephi.Accounts.register_user/1`), holds no
  # permission over other users.
  @permissions [
    {"users:view", "View Users", "View user profiles and listings", ["manager"]},
    {"users:create", "Create Users", "Create new user accounts", ["manager"]},
    {"users:edit", "Edit Users", "Edit user information", ["manager"]},
    {"users:delete", "Delete Users", "Delete user accounts", []},
    {"roles:view", "View Roles", "View roles and their permissions", ["manager"]},
    {"roles:create", "Create Roles", "Create new roles", []},
    {"roles:edit", "Edit Roles", "Edit role information", []},
    {"roles:delete", "Delete Roles", "Delete roles", []},
    {"roles:assign", "Assign Roles", "Assign roles to users", []},
    {"permissions:view", "View Permissions", "View permissions", []},
    {"permissions:create", "Create Permissions", "Create new permissions", []},
    {"permissions:edit", "Edit Permissions", "Edit permission information", []},
    {"permissions:delete", "Delete Permissions", "Delete permissions", []},
    {"permissions:assign", "Assign Permissions", "Assign permissions to roles or users", []},
    {"system:settings", "Access System Settings", "Access system configuration", []},
    {"system:logs", "View System Logs", "View system logs and audit trails", []},
    {"system:manage", "Manage System", "Perform system maintenance", []},
    # A broadcast reaches every connected user, so only admins may send one.
    {"notifications:broadcast", "Broadcast Notifications",
     "Send a notification to every connected user", []}
  ]

  @type stale_grant :: {role_slug :: String.t(), permission_slug :: String.t()}

  @type admin_result ::
          {:created, String.t()}
          | {:existing, String.t()}
          | {:default_created, String.t()}
          | {:default_existing, String.t()}
          | :skipped

  @doc """
  The default roles, in the order they are created.
  """
  def roles, do: @roles

  @doc """
  The default permissions as `%{slug, name, description, roles}` maps, where
  `roles` are the role slugs granted the permission directly.
  """
  def permissions do
    for {slug, name, description, roles} <- @permissions do
      %{slug: slug, name: name, description: description, roles: Enum.uniq(["admin" | roles])}
    end
  end

  @doc """
  Seeds the database.

  ## Options

    * `:admin_email`, `:admin_password` - the administrator; default to the
      `ADMIN_EMAIL` and `ADMIN_PASSWORD` environment variables
    * `:admin` - `:required`, `:default` or `:optional`; defaults to the
      application configuration (see the module documentation)

  Returns `{:ok, %{admin: admin_result, stale_grants: [stale_grant]}}`, or
  `{:error, message}` without having changed anything.
  """
  @spec run(keyword()) ::
          {:ok, %{admin: admin_result(), stale_grants: [stale_grant()]}} | {:error, String.t()}
  def run(opts \\ []) do
    with {:ok, admin} <- admin_credentials(opts) do
      Repo.transact(fn ->
        roles = Map.new(@roles, &{&1.slug, ensure!(Role, &1)})

        permissions =
          Map.new(permissions(), fn permission ->
            {permission.slug, ensure!(Permission, Map.delete(permission, :roles))}
          end)

        link!(
          "role_roles",
          :child_role_id,
          :parent_role_id,
          for({child, parent} <- @role_hierarchy, do: {roles[child].id, roles[parent].id})
        )

        link!(
          "role_permissions",
          :role_id,
          :permission_id,
          for(
            permission <- permissions(),
            role <- permission.roles,
            do: {roles[role].id, permissions[permission.slug].id}
          )
        )

        with {:ok, result} <- seed_admin(admin, roles["admin"]) do
          {:ok, %{admin: result, stale_grants: stale_grants()}}
        end
      end)
    end
  end

  # Inserts the row identified by `slug` unless it exists, and returns it,
  # marked as a system row either way.
  defp ensure!(schema, %{slug: slug} = attrs) do
    case Repo.get_by(schema, slug: slug) do
      nil ->
        schema.__struct__()
        |> schema.create_changeset(attrs)
        |> Ecto.Changeset.put_change(:is_system, true)
        |> Repo.insert!()

      %{is_system: true} = existing ->
        existing

      existing ->
        existing |> Ecto.Changeset.change(is_system: true) |> Repo.update!()
    end
  end

  @doc """
  Grants between seeded roles and seeded permissions that exist in the
  database but that the seed does not make. See "Grants the seed no longer
  makes".
  """
  @spec stale_grants() :: [stale_grant()]
  def stale_grants do
    seeded = MapSet.new(for p <- permissions(), role <- p.roles, do: {role, p.slug})

    from(rp in "role_permissions",
      join: r in Role,
      on: r.id == rp.role_id,
      join: p in Permission,
      on: p.id == rp.permission_id,
      where: r.slug in ^Enum.map(@roles, & &1.slug),
      where: p.slug in ^Enum.map(@permissions, &elem(&1, 0)),
      order_by: [r.slug, p.slug],
      select: {r.slug, p.slug}
    )
    |> Repo.all()
    |> Enum.reject(&MapSet.member?(seeded, &1))
  end

  defp link!(table, left, right, pairs) do
    now = NaiveDateTime.utc_now(:second)

    rows =
      for {left_id, right_id} <- pairs do
        %{left => left_id, right => right_id, inserted_at: now, updated_at: now}
      end

    Repo.insert_all(table, rows, on_conflict: :nothing)
  end

  defp seed_admin(:skip, _role), do: {:ok, :skipped}

  defp seed_admin({source, %{email: email, password: password}}, role) do
    with {:ok, status, user} <- find_or_create_admin(email, password) do
      link!("user_roles", :user_id, :role_id, [{user.id, role.id}])

      case source do
        :env -> {:ok, {status, user.email}}
        :default -> {:ok, {:"default_#{status}", user.email}}
      end
    end
  end

  defp find_or_create_admin(email, password) do
    case Accounts.get_user_by_email(email) do
      %User{} = user ->
        {:ok, :existing, user}

      nil ->
        case Accounts.create_user(%{email: email, password: password}) do
          {:ok, user} -> {:ok, :created, user}
          {:error, changeset} -> {:error, admin_error(changeset)}
        end
    end
  end

  defp admin_credentials(opts) do
    email = Keyword.get_lazy(opts, :admin_email, fn -> env("ADMIN_EMAIL") end)
    password = Keyword.get_lazy(opts, :admin_password, fn -> env("ADMIN_PASSWORD") end)
    mode = Keyword.get_lazy(opts, :admin, &configured_mode/0)

    case {email, password, mode} do
      {email, password, _mode} when is_binary(email) and is_binary(password) ->
        {:ok, {:env, %{email: email, password: password}}}

      {nil, nil, :default} ->
        {:ok, {:default, @default_admin}}

      {nil, nil, :optional} ->
        {:ok, :skip}

      {nil, nil, _required} ->
        {:error,
         "ADMIN_EMAIL and ADMIN_PASSWORD are required to seed this environment. " <>
           "Set them to the email and password of the first administrator."}

      _only_one ->
        {:error, "set both ADMIN_EMAIL and ADMIN_PASSWORD, or neither"}
    end
  end

  defp configured_mode do
    :rephi |> Application.get_env(__MODULE__, []) |> Keyword.get(:admin, :required)
  end

  defp env(name) do
    case System.get_env(name) do
      nil -> nil
      value -> if String.trim(value) == "", do: nil, else: value
    end
  end

  defp admin_error(changeset) do
    errors =
      changeset
      |> Ecto.Changeset.traverse_errors(fn {message, opts} ->
        Regex.replace(~r"%{(\w+)}", message, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)
      |> Enum.map_join("; ", fn {field, messages} -> "#{field} #{Enum.join(messages, ", ")}" end)

    "the administrator could not be created: #{errors}"
  end
end
