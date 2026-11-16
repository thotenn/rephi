defmodule Rephi.Authorization do
  @moduledoc """
  Role-based access control: roles, permissions, who holds what, and the
  checks.

  ## Model

    * A **permission** is a single right, identified by its slug
      (`"users:edit"`). The `category:action` form is a naming convention:
      there are no wildcards.
    * A **role** groups permissions. A role can have **parent roles**: it
      grants its own permissions plus every permission of its ancestors,
      transitively (`admin → manager → user` in the default seed).
    * A **user** holds roles and, optionally, permissions granted directly.

  What a user may do is the union of its direct permissions and the
  permissions of every role it holds, directly or through the hierarchy.
  Both `can?/2` and `has_role?/2` follow the hierarchy (an `admin` *is* a
  `manager`); `has_direct_role?/2` only looks at assigned roles.

  `admin` is not a superuser: it can do what its permissions say. A new
  permission has to be granted to it like to any other role. It is special
  in three ways only: its slug is configurable (`admin_role_slug/0`), at
  least one user must always hold it (`preserving_admins/1`), and its
  holders can grant any role or permission (`can_grant_role?/2`).

  ## Checking

  Every check resolves the hierarchy in **one query** (a recursive CTE). In
  a request, prefer the `Rephi.Authorization.Access` loaded once by the
  authentication pipeline: the same functions accept it and answer without
  querying.

      Authorization.can?(user, "users:edit")              # 1 query
      access = Authorization.load_access(user)            # 1 query
      Authorization.can?(access, "users:edit")            # 0 queries
      Authorization.can_all?(access, ["roles:view", "roles:edit"])

  Checks never raise: a `nil` or unsaved user, a slug that is not a string
  or a permission that does not exist is simply `false`.

  ## Integrity guarantees

    * The hierarchy has no cycles (`assign_parent_role/3`); reads terminate
      even if one is inserted by hand.
    * System roles and permissions (`is_system`, set by `Rephi.Seeds`) cannot
      be deleted nor have their slug changed, and the links of the seeded
      hierarchy (system links) cannot be removed.
    * The last user holding the admin role cannot lose it, through any path
      (`remove_role_from_user/3`, `Rephi.Accounts.delete_user/1`,
      `delete_role/1`, `remove_parent_role/3`).
    * With the `:actor` option, assignments refuse to grant what the actor
      does not hold (`can_grant_role?/2`, `can_grant_permission?/2`,
      `can_link_roles?/3`).

  ## Assignment options

  The functions that grant or revoke (`assign_*`, `remove_*`) accept these
  options, as a keyword list or a map (`remove_*` only reads `:actor`):

    * `:actor` - the user (or its `Access`) making the change. When given,
      the change is refused with `{:error, :escalation}` unless the actor can
      grant what is being granted or revoked (`can_grant_role?/2`,
      `can_grant_permission?/2`, `can_link_roles?/3` for the hierarchy), and
      `assigned_by` defaults to its id. Without it nothing is checked: that
      is for seeds and trusted code. The controllers always pass it.
    * `:assigned_by` - id of the user recorded as the one who granted it (an
      existing user)
    * `:notes` - free text, at most 2000 characters

  ## Errors

  Besides `{:error, %Ecto.Changeset{}}` and `{:error, :not_found}`, functions
  return these reasons (rendered by `RephiWeb.FallbackController`):

    * `:system_role`, `:system_permission` - it cannot be deleted
    * `:system_link` - the link is part of the seeded hierarchy
    * `:last_admin` - nobody would hold the admin role any more
    * `:escalation` - the actor cannot grant or revoke what it does not hold
    * `:inherited_permission` - the role gets the permission from a parent
      role, it is not assigned to the role itself
    * `:granted_through_role` - the user gets the permission from a role, it
      is not granted to the user directly

  A cycle in the hierarchy is a changeset error on `:parent_role_id` whose
  options carry `validation: :cycle` (or `constraint: :check` for a role
  linked to itself, caught by the database).
  """

  import Ecto.Query, warn: false

  alias Rephi.{Pagination, Repo}
  alias Rephi.Accounts.User

  alias Rephi.Authorization.{
    Access,
    Permission,
    Role,
    RolePermission,
    RoleRole,
    UserPermission,
    UserRole
  }

  @typedoc "Whose authorization is checked: a user, or its loaded `Access`."
  @type subject :: User.t() | Access.t() | nil

  ## Configuration

  @doc """
  The slug of the administrator role: `config :rephi, Rephi.Authorization,
  admin_role: "admin"` (the default).
  """
  @spec admin_role_slug() :: String.t()
  def admin_role_slug do
    :rephi |> Application.get_env(__MODULE__, []) |> Keyword.get(:admin_role, "admin")
  end

  ## Roles

  @doc """
  Returns every role, ordered by slug.
  """
  def list_roles do
    Repo.all(from r in Role, order_by: [asc: r.slug])
  end

  @doc """
  Returns one page of roles, ordered by slug. See `Rephi.Pagination`.
  """
  def paginate_roles(params \\ %{}) do
    Pagination.paginate(from(r in Role, order_by: [asc: r.slug, asc: r.id]), params)
  end

  @doc """
  Gets a role by id, or `nil`. Never raises: an id that cannot be a primary
  key (`"abc"`, out of range) is not found.
  """
  def get_role(id) do
    case fetch_role(id) do
      {:ok, role} -> role
      {:error, :not_found} -> nil
    end
  end

  @doc """
  Fetches a role by id: `{:ok, role}` or `{:error, :not_found}`.
  """
  def fetch_role(id), do: Repo.fetch(Role, id)

  @doc """
  Gets a role by slug, or `nil`.
  """
  def get_role_by_slug(slug) when is_binary(slug), do: Repo.get_by(Role, slug: slug)
  def get_role_by_slug(_slug), do: nil

  @doc """
  Creates a role. `is_system` cannot be set this way.

      iex> Authorization.create_role(%{name: "Editor", slug: "editor"})
      {:ok, %Role{slug: "editor"}}

  """
  def create_role(attrs \\ %{}) do
    %Role{}
    |> Role.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a role. The slug of a system role cannot change (validation error
  on `:slug`).
  """
  def update_role(%Role{} = role, attrs) do
    role
    |> Role.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a role, with its assignments to users, its permissions and its
  links in the hierarchy.

  Returns `{:error, :system_role}` for a system role, and
  `{:error, :last_admin}` if nobody would hold the admin role afterwards
  (the role inherited from it).
  """
  def delete_role(%Role{is_system: true}), do: {:error, :system_role}

  def delete_role(%Role{} = role) do
    preserving_admins(fn -> Repo.delete(role) end)
  end

  ## Permissions

  @doc """
  Returns every permission, ordered by slug.
  """
  def list_permissions do
    Repo.all(from p in Permission, order_by: [asc: p.slug])
  end

  @doc """
  Returns one page of permissions, ordered by slug. See `Rephi.Pagination`.
  """
  def paginate_permissions(params \\ %{}) do
    Pagination.paginate(from(p in Permission, order_by: [asc: p.slug, asc: p.id]), params)
  end

  @doc """
  Gets a permission by id, or `nil`. Never raises.
  """
  def get_permission(id) do
    case fetch_permission(id) do
      {:ok, permission} -> permission
      {:error, :not_found} -> nil
    end
  end

  @doc """
  Fetches a permission by id: `{:ok, permission}` or `{:error, :not_found}`.
  """
  def fetch_permission(id), do: Repo.fetch(Permission, id)

  @doc """
  Gets a permission by slug, or `nil`.
  """
  def get_permission_by_slug(slug) when is_binary(slug), do: Repo.get_by(Permission, slug: slug)
  def get_permission_by_slug(_slug), do: nil

  @doc """
  Creates a permission. `is_system` cannot be set this way.

      iex> Authorization.create_permission(%{name: "Export", slug: "reports:export"})
      {:ok, %Permission{slug: "reports:export"}}

  """
  def create_permission(attrs \\ %{}) do
    %Permission{}
    |> Permission.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a permission. The slug of a system permission cannot change, and a
  permission cannot be its own parent (validation errors).
  """
  def update_permission(%Permission{} = permission, attrs) do
    permission
    |> Permission.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a permission and every grant of it. Its children (`parent_id`)
  lose their parent.

  Returns `{:error, :system_permission}` for a system permission.
  """
  def delete_permission(%Permission{is_system: true}), do: {:error, :system_permission}
  def delete_permission(%Permission{} = permission), do: Repo.delete(permission)

  ## Assignments

  @doc """
  Assigns a role to a user.

  Returns `{:ok, %UserRole{}}`, `{:error, changeset}` (already assigned:
  unique constraint on `:user_id`; unknown user, role or assigner) or
  `{:error, :escalation}`. See "Assignment options".

      iex> Authorization.assign_role_to_user(user, role, actor: current_user, notes: "Promoted")
      {:ok, %UserRole{}}

  """
  def assign_role_to_user(%User{} = user, %Role{} = role, opts \\ []) do
    with :ok <- check_actor(opts, &can_grant_role?(&1, role)) do
      %UserRole{}
      |> UserRole.changeset(%{
        user_id: user.id,
        role_id: role.id,
        assigned_by: assigned_by(opts),
        notes: opts[:notes]
      })
      |> Repo.insert()
    end
  end

  @doc """
  Removes a role from a user.

  Returns `:ok`, `{:error, :not_found}` (it was not assigned; also when two
  requests race to remove it), `{:error, :last_admin}` or
  `{:error, :escalation}` (with `:actor`, revoking needs the same rights as
  granting).
  """
  def remove_role_from_user(user, role, opts \\ [])

  def remove_role_from_user(%User{id: user_id} = user, %Role{id: role_id} = role, opts)
      when is_integer(user_id) and is_integer(role_id) do
    with :ok <- check_actor(opts, &can_grant_role?(&1, role)),
         {:ok, :removed} <-
           preserving_admins(fn ->
             from(ur in UserRole, where: ur.user_id == ^user.id and ur.role_id == ^role.id)
             |> delete_one()
           end) do
      :ok
    end
  end

  def remove_role_from_user(_user, _role, _opts), do: {:error, :not_found}

  @doc """
  Returns the roles assigned to a user (not the inherited ones), ordered by
  slug. Always reads the database, never `user.roles`.
  """
  def get_user_roles(%User{id: user_id}) when is_integer(user_id) do
    Repo.all(
      from r in Role,
        join: ur in UserRole,
        on: ur.role_id == r.id,
        where: ur.user_id == ^user_id,
        order_by: [asc: r.slug]
    )
  end

  def get_user_roles(_user), do: []

  @doc """
  Grants a permission directly to a user. Same results and options as
  `assign_role_to_user/3`.
  """
  def assign_permission_to_user(%User{} = user, %Permission{} = permission, opts \\ []) do
    with :ok <- check_actor(opts, &can_grant_permission?(&1, permission)) do
      %UserPermission{}
      |> UserPermission.changeset(%{
        user_id: user.id,
        permission_id: permission.id,
        assigned_by: assigned_by(opts),
        notes: opts[:notes]
      })
      |> Repo.insert()
    end
  end

  @doc """
  Revokes a permission granted directly to a user.

  Returns `:ok`, `{:error, :escalation}`, `{:error, :granted_through_role}`
  when the user does not have it directly but holds it through one of its
  roles (revoke it there, or remove the role), or `{:error, :not_found}`.
  """
  def remove_permission_from_user(user, permission, opts \\ [])

  def remove_permission_from_user(
        %User{id: user_id} = user,
        %Permission{id: permission_id} = permission,
        opts
      )
      when is_integer(user_id) and is_integer(permission_id) do
    with :ok <- check_actor(opts, &can_grant_permission?(&1, permission)) do
      from(up in UserPermission,
        where: up.user_id == ^user.id and up.permission_id == ^permission.id
      )
      |> delete_one()
      |> case do
        {:ok, :removed} ->
          :ok

        {:error, :not_found} ->
          if can?(user, permission),
            do: {:error, :granted_through_role},
            else: {:error, :not_found}
      end
    end
  end

  def remove_permission_from_user(_user, _permission, _opts), do: {:error, :not_found}

  @doc """
  Grants a permission to a role. Same results and options as
  `assign_role_to_user/3`.
  """
  def assign_permission_to_role(%Role{} = role, %Permission{} = permission, opts \\ []) do
    with :ok <- check_actor(opts, &can_grant_permission?(&1, permission)) do
      %RolePermission{}
      |> RolePermission.changeset(%{
        role_id: role.id,
        permission_id: permission.id,
        assigned_by: assigned_by(opts),
        notes: opts[:notes]
      })
      |> Repo.insert()
    end
  end

  @doc """
  Revokes a permission from a role.

  Returns `:ok`, `{:error, :escalation}`, `{:error, :inherited_permission}`
  when the role does not hold it itself but inherits it from a parent role
  (revoke it there), or `{:error, :not_found}`.
  """
  def remove_permission_from_role(role, permission, opts \\ [])

  def remove_permission_from_role(
        %Role{id: role_id} = role,
        %Permission{id: permission_id} = permission,
        opts
      )
      when is_integer(role_id) and is_integer(permission_id) do
    with :ok <- check_actor(opts, &can_grant_permission?(&1, permission)) do
      from(rp in RolePermission,
        where: rp.role_id == ^role.id and rp.permission_id == ^permission.id
      )
      |> delete_one()
      |> case do
        {:ok, :removed} ->
          :ok

        {:error, :not_found} ->
          if role_has_permission?(role, permission),
            do: {:error, :inherited_permission},
            else: {:error, :not_found}
      end
    end
  end

  def remove_permission_from_role(_role, _permission, _opts), do: {:error, :not_found}

  ## Hierarchy

  @doc """
  Makes `child` inherit every permission of `parent`.

  Returns `{:ok, %RoleRole{}}`, `{:error, :escalation}` (see
  `can_link_roles?/3`) or `{:error, changeset}`: already linked (unique
  constraint), unknown role or assigner, notes too long, or a cycle - it
  would make a role its own ancestor (`child == parent`, or `child` is
  already an ancestor of `parent`); a cycle error on `:parent_role_id`
  carries `validation: :cycle`.

  The check and the insert run in one transaction holding a lock on
  `role_roles`, so two concurrent calls cannot close a cycle between them.
  Accepts the "Assignment options".

      iex> Authorization.assign_parent_role(editor, author, actor: current_access)
      {:ok, %RoleRole{}}

  """
  def assign_parent_role(%Role{} = child, %Role{} = parent, opts \\ []) do
    with :ok <- check_actor(opts, &can_link_roles?(&1, child, parent)) do
      changeset =
        RoleRole.changeset(%RoleRole{}, %{
          child_role_id: child.id,
          parent_role_id: parent.id,
          assigned_by: assigned_by(opts),
          notes: opts[:notes]
        })

      Repo.transact(fn ->
        Repo.query!("LOCK TABLE role_roles IN SHARE ROW EXCLUSIVE MODE")

        if changeset.valid? and ancestor?(child.id, parent.id) do
          {:error,
           Ecto.Changeset.add_error(
             changeset,
             :parent_role_id,
             "would make the role inherit from itself",
             validation: :cycle
           )}
        else
          Repo.insert(changeset)
        end
      end)
    end
  end

  @doc """
  Removes a parent from a role.

  Returns `:ok`, `{:error, :not_found}` (not linked), `{:error, :escalation}`
  (with `:actor`, see `can_link_roles?/3`), `{:error, :system_link}` (a link
  of the seeded hierarchy) or `{:error, :last_admin}` (the link was how the
  last admins held the role).
  """
  def remove_parent_role(child, parent, opts \\ [])

  def remove_parent_role(%Role{id: child_id} = child, %Role{id: parent_id} = parent, opts)
      when is_integer(child_id) and is_integer(parent_id) do
    link =
      from rr in RoleRole,
        where: rr.child_role_id == ^child_id and rr.parent_role_id == ^parent_id

    with :ok <- check_actor(opts, &can_link_roles?(&1, child, parent)),
         {:ok, :removed} <-
           preserving_admins(fn ->
             # A single DELETE that skips system links, as in `delete_one/1`.
             case Repo.delete_all(where(link, [rr], not rr.is_system)) do
               {0, _} ->
                 if Repo.exists?(link), do: {:error, :system_link}, else: {:error, :not_found}

               {_count, _} ->
                 {:ok, :removed}
             end
           end) do
      :ok
    end
  end

  def remove_parent_role(_child, _parent, _opts), do: {:error, :not_found}

  @doc """
  The direct parents of a role (not their ancestors), ordered by slug, each
  with its link: `[{%Role{}, %RoleRole{}}]`. One query.
  """
  def list_parent_roles(%Role{id: role_id}) when is_integer(role_id) do
    Repo.all(
      from r in Role,
        join: rr in RoleRole,
        on: rr.parent_role_id == r.id,
        where: rr.child_role_id == ^role_id,
        order_by: [asc: r.slug],
        select: {r, rr}
    )
  end

  def list_parent_roles(_role), do: []

  @doc """
  The direct children of a role (the roles that inherit from it directly),
  ordered by slug, each with its link: `[{%Role{}, %RoleRole{}}]`. One query.
  """
  def list_child_roles(%Role{id: role_id}) when is_integer(role_id) do
    Repo.all(
      from r in Role,
        join: rr in RoleRole,
        on: rr.child_role_id == r.id,
        where: rr.parent_role_id == ^role_id,
        order_by: [asc: r.slug],
        select: {r, rr}
    )
  end

  def list_child_roles(_role), do: []

  # Whether `role_id` is `of_id` or one of its ancestors.
  defp ancestor?(role_id, of_id) do
    from(t in "role_tree", where: t.id == ^role_id, select: 1)
    |> with_role_tree(role_seed(of_id))
    |> Repo.exists?()
  end

  ## Checks

  @doc """
  Loads everything a user may do (`Rephi.Authorization.Access`) in a single
  query, whatever the depth of the role hierarchy.

  A `nil` or unsaved user gets an empty `Access`.
  """
  @spec load_access(User.t() | nil) :: Access.t()
  def load_access(%User{id: user_id}) when is_integer(user_id) do
    assigned_roles =
      from r in Role,
        join: ur in UserRole,
        on: ur.role_id == r.id,
        where: ur.user_id == ^user_id,
        select: %{kind: "assigned_role", id: r.id, name: r.name, slug: r.slug}

    held_roles =
      from r in Role,
        join: t in "role_tree",
        on: t.id == r.id,
        select: %{kind: "held_role", id: r.id, name: r.name, slug: r.slug}

    permissions =
      user_id
      |> effective_permissions()
      |> select([p], %{kind: "permission", id: p.id, name: p.name, slug: p.slug})

    rows =
      assigned_roles
      |> union_all(^held_roles)
      |> union_all(^permissions)
      |> with_role_tree(user_seed(user_id))
      |> Repo.all()

    grouped = Enum.group_by(rows, & &1.kind, &Map.delete(&1, :kind))
    roles = grouped |> Map.get("assigned_role", []) |> Enum.sort_by(& &1.slug)
    permissions = grouped |> Map.get("permission", []) |> Enum.sort_by(& &1.slug)

    %Access{
      user_id: user_id,
      roles: roles,
      role_slugs: grouped |> Map.get("held_role", []) |> MapSet.new(& &1.slug),
      permissions: permissions,
      permission_slugs: MapSet.new(permissions, & &1.slug)
    }
  end

  def load_access(_user), do: %Access{}

  @doc """
  Whether the user holds a permission: directly, through a role, or through
  an ancestor of one of its roles.

  `permission` is a slug or a `%Permission{}`. One query for a user, none
  for an `Access`. Anything else is `false`.

      iex> Authorization.can?(user, "users:edit")
      true

      iex> Authorization.can?(nil, "users:edit")
      false

  """
  @spec can?(subject(), String.t() | Permission.t() | term()) :: boolean()
  def can?(%Access{permission_slugs: slugs}, slug) when is_binary(slug),
    do: MapSet.member?(slugs, slug)

  def can?(%Access{} = access, %Permission{slug: slug}) when is_binary(slug),
    do: can?(access, slug)

  def can?(%User{id: user_id}, slug) when is_integer(user_id) and is_binary(slug) do
    user_id
    |> effective_permissions()
    |> where([p], p.slug == ^slug)
    |> with_role_tree(user_seed(user_id))
    |> Repo.exists?()
  end

  def can?(%User{id: user_id}, %Permission{id: permission_id})
      when is_integer(user_id) and is_integer(permission_id) do
    user_id
    |> effective_permissions()
    |> where([p], p.id == ^permission_id)
    |> with_role_tree(user_seed(user_id))
    |> Repo.exists?()
  end

  def can?(_subject, _permission), do: false

  @doc """
  Whether the user holds at least one of the permissions (slugs). One query
  for a user, none for an `Access`. An empty list is `false`.
  """
  @spec can_any?(subject(), [String.t()]) :: boolean()
  def can_any?(subject, slugs) when is_list(slugs) do
    case Enum.filter(slugs, &is_binary/1) do
      [] -> false
      slugs -> count_held(subject, slugs) > 0
    end
  end

  def can_any?(_subject, _slugs), do: false

  @doc """
  Whether the user holds every one of the permissions (slugs). One query for
  a user, none for an `Access`. An empty list is `true` (nothing is
  required); a list with anything that is not a string is `false`.
  """
  @spec can_all?(subject(), [String.t()]) :: boolean()
  def can_all?(subject, slugs) when is_list(slugs) do
    cond do
      not Enum.all?(slugs, &is_binary/1) -> false
      slugs == [] -> valid_subject?(subject)
      true -> count_held(subject, Enum.uniq(slugs)) == length(Enum.uniq(slugs))
    end
  end

  def can_all?(_subject, _slugs), do: false

  defp count_held(%Access{permission_slugs: held}, slugs),
    do: Enum.count(Enum.uniq(slugs), &MapSet.member?(held, &1))

  defp count_held(%User{id: user_id}, slugs) when is_integer(user_id) do
    user_id
    |> effective_permissions()
    |> where([p], p.slug in ^slugs)
    |> select([p], count(p.id))
    |> with_role_tree(user_seed(user_id))
    |> Repo.one()
  end

  defp count_held(_subject, _slugs), do: 0

  defp valid_subject?(%Access{user_id: id}), do: is_integer(id)
  defp valid_subject?(%User{id: id}), do: is_integer(id)
  defp valid_subject?(_subject), do: false

  @doc """
  Whether the user holds a role, assigned or inherited: a user with `admin`
  (child of `manager`) holds `manager` too. `role` is a slug or a `%Role{}`.

  One query for a user, none for an `Access`. Anything else is `false`. Use
  `has_direct_role?/2` to ignore the hierarchy.
  """
  @spec has_role?(subject(), String.t() | Role.t() | term()) :: boolean()
  def has_role?(%Access{role_slugs: slugs}, slug) when is_binary(slug),
    do: MapSet.member?(slugs, slug)

  def has_role?(%Access{} = access, %Role{slug: slug}) when is_binary(slug),
    do: has_role?(access, slug)

  def has_role?(%User{id: user_id}, slug) when is_integer(user_id) and is_binary(slug) do
    held_role(user_id, dynamic([r], r.slug == ^slug))
  end

  def has_role?(%User{id: user_id}, %Role{id: role_id})
      when is_integer(user_id) and is_integer(role_id) do
    held_role(user_id, dynamic([r], r.id == ^role_id))
  end

  def has_role?(_subject, _role), do: false

  defp held_role(user_id, condition) do
    from(r in Role, join: t in "role_tree", on: t.id == r.id, where: ^condition)
    |> with_role_tree(user_seed(user_id))
    |> Repo.exists?()
  end

  @doc """
  Whether the role is assigned to the user itself, ignoring the hierarchy.
  `role` is a slug or a `%Role{}`. One query for a user, none for an
  `Access`.
  """
  @spec has_direct_role?(subject(), String.t() | Role.t() | term()) :: boolean()
  def has_direct_role?(%Access{roles: roles}, slug) when is_binary(slug),
    do: Enum.any?(roles, &(&1.slug == slug))

  def has_direct_role?(%Access{} = access, %Role{slug: slug}) when is_binary(slug),
    do: has_direct_role?(access, slug)

  def has_direct_role?(%User{id: user_id}, slug) when is_integer(user_id) and is_binary(slug) do
    Repo.exists?(
      from ur in UserRole,
        join: r in Role,
        on: r.id == ur.role_id,
        where: ur.user_id == ^user_id and r.slug == ^slug
    )
  end

  def has_direct_role?(%User{id: user_id}, %Role{id: role_id})
      when is_integer(user_id) and is_integer(role_id) do
    Repo.exists?(from ur in UserRole, where: ur.user_id == ^user_id and ur.role_id == ^role_id)
  end

  def has_direct_role?(_subject, _role), do: false

  @doc """
  Whether the user holds the admin role (`admin_role_slug/0`), assigned or
  inherited.
  """
  @spec admin?(subject()) :: boolean()
  def admin?(subject), do: has_role?(subject, admin_role_slug())

  @doc """
  Whether `actor` may grant (or revoke) `role`: it is an admin, or it holds
  the role itself, so it hands out nothing it does not already have.
  """
  @spec can_grant_role?(subject(), Role.t()) :: boolean()
  def can_grant_role?(actor, %Role{} = role), do: admin?(actor) or has_role?(actor, role)
  def can_grant_role?(_actor, _role), do: false

  @doc """
  Whether `actor` may grant (or revoke) `permission`: it is an admin, or it
  holds the permission itself.
  """
  @spec can_grant_permission?(subject(), Permission.t()) :: boolean()
  def can_grant_permission?(actor, %Permission{} = permission),
    do: admin?(actor) or can?(actor, permission)

  def can_grant_permission?(_actor, _permission), do: false

  @doc """
  Whether `actor` may link `parent` to `child` in the hierarchy, or unlink
  it: it is an admin, or it holds both roles (assigned or inherited).

  Linking hands every holder of `child` the permissions of `parent`, so the
  actor must be able to grant `parent`; and it changes what `child` grants,
  so the actor must hold `child` too - a non-admin cannot reshape a role
  above its own reach (the admin role, for one).
  """
  @spec can_link_roles?(subject(), Role.t(), Role.t()) :: boolean()
  def can_link_roles?(actor, %Role{} = child, %Role{} = parent),
    do: admin?(actor) or (has_role?(actor, child) and has_role?(actor, parent))

  def can_link_roles?(_actor, _child, _parent), do: false

  @doc """
  Whether `actor` may change or delete `user`: it is an admin, or it holds
  every role assigned to `user`. Keeps a user from acting on someone with
  more rights than itself.
  """
  @spec can_manage_user?(subject(), User.t()) :: boolean()
  def can_manage_user?(actor, %User{} = user) do
    valid_subject?(actor) and
      (admin?(actor) or Enum.all?(get_user_roles(user), &has_role?(actor, &1)))
  end

  def can_manage_user?(_actor, _user), do: false

  @doc """
  Every effective permission of a user (direct, through roles and inherited),
  ordered by slug. One query. A `nil` or unsaved user has none.
  """
  def get_user_permissions(%User{id: user_id}) when is_integer(user_id) do
    user_id
    |> effective_permissions()
    |> order_by([p], asc: p.slug)
    |> with_role_tree(user_seed(user_id))
    |> Repo.all()
  end

  def get_user_permissions(_user), do: []

  @doc """
  The permissions of a user split by where they come from, in two queries:

    * `direct` - granted to the user itself, as `[%UserPermission{}]` with
      `permission` loaded (who granted it, notes, when), the ones
      `remove_permission_from_user/3` can revoke;
    * `effective` - everything the user may do (what `load_access/1`
      computes), as `[%{permission: %Permission{}, direct: boolean, roles:
      [%{id, name, slug}]}]`: `direct` when it is granted to the user itself,
      and `roles` the roles that grant it, assigned to the user or inherited
      through the hierarchy (the role the permission is assigned to).

  Both are ordered by slug (`roles` too). A `nil` or unsaved user has none.
  """
  def get_user_permission_sources(%User{id: user_id}) when is_integer(user_id) do
    direct =
      Repo.all(
        from up in UserPermission,
          join: p in assoc(up, :permission),
          where: up.user_id == ^user_id,
          order_by: [asc: p.slug],
          preload: [permission: p]
      )

    from_roles =
      from(p in Permission,
        join: rp in RolePermission,
        on: rp.permission_id == p.id,
        join: t in "role_tree",
        on: t.id == rp.role_id,
        join: r in Role,
        on: r.id == rp.role_id,
        order_by: [asc: p.slug, asc: r.slug],
        select: {p, %{id: r.id, name: r.name, slug: r.slug}}
      )
      |> with_role_tree(user_seed(user_id))
      |> Repo.all()
      |> Enum.chunk_by(fn {p, _role} -> p.id end)
      |> Map.new(fn [{p, _} | _] = chunk -> {p.id, {p, Enum.map(chunk, &elem(&1, 1))}} end)

    direct_by_id = Map.new(direct, &{&1.permission_id, &1.permission})

    effective =
      (Map.keys(direct_by_id) ++ Map.keys(from_roles))
      |> Enum.uniq()
      |> Enum.map(fn id ->
        {from_role, roles} = Map.get(from_roles, id, {nil, []})

        %{
          permission: Map.get(direct_by_id, id, from_role),
          direct: Map.has_key?(direct_by_id, id),
          roles: roles
        }
      end)
      |> Enum.sort_by(& &1.permission.slug)

    %{direct: direct, effective: effective}
  end

  def get_user_permission_sources(_user), do: %{direct: [], effective: []}

  @doc """
  Every permission a role grants: its own and its ancestors', ordered by
  slug. One query.
  """
  def get_role_permissions(%Role{id: role_id}) when is_integer(role_id) do
    from(p in Permission, where: p.id in subquery(role_tree_permission_ids()), order_by: p.slug)
    |> with_role_tree(role_seed(role_id))
    |> Repo.all()
  end

  def get_role_permissions(_role), do: []

  @doc """
  The permissions of a role split by where they come from, in one query:

    * `direct` - assigned to the role itself (`[%Permission{}]`), the ones
      `remove_permission_from_role/3` can revoke;
    * `inherited` - granted by an ancestor and **not** assigned to the role
      itself, as `{%Permission{}, [%{id, name, slug}]}` with the ancestor
      roles that grant it.

  Both are ordered by slug.
  """
  def get_role_permission_sources(%Role{id: role_id}) when is_integer(role_id) do
    rows =
      from(p in Permission,
        join: rp in RolePermission,
        on: rp.permission_id == p.id,
        join: t in "role_tree",
        on: t.id == rp.role_id,
        join: r in Role,
        on: r.id == rp.role_id,
        order_by: [asc: p.slug, asc: r.slug],
        select: {p, %{id: r.id, name: r.name, slug: r.slug}}
      )
      |> with_role_tree(role_seed(role_id))
      |> Repo.all()

    {own, from_ancestors} = Enum.split_with(rows, fn {_p, source} -> source.id == role_id end)
    direct = Enum.map(own, &elem(&1, 0))
    direct_ids = MapSet.new(direct, & &1.id)

    inherited =
      from_ancestors
      |> Enum.reject(fn {p, _source} -> MapSet.member?(direct_ids, p.id) end)
      |> Enum.chunk_by(fn {p, _source} -> p.id end)
      |> Enum.map(fn [{p, _} | _] = chunk -> {p, Enum.map(chunk, &elem(&1, 1))} end)

    %{direct: direct, inherited: inherited}
  end

  def get_role_permission_sources(_role), do: %{direct: [], inherited: []}

  @doc """
  Whether a role grants a permission (slug or `%Permission{}`), its own or
  inherited. One query; anything else is `false`.
  """
  def role_has_permission?(%Role{id: role_id}, slug)
      when is_integer(role_id) and is_binary(slug) do
    role_grants(role_id, dynamic([p], p.slug == ^slug))
  end

  def role_has_permission?(%Role{id: role_id}, %Permission{id: permission_id})
      when is_integer(role_id) and is_integer(permission_id) do
    role_grants(role_id, dynamic([p], p.id == ^permission_id))
  end

  def role_has_permission?(_role, _permission), do: false

  defp role_grants(role_id, condition) do
    from(p in Permission, where: p.id in subquery(role_tree_permission_ids()), where: ^condition)
    |> with_role_tree(role_seed(role_id))
    |> Repo.exists?()
  end

  ## Admin guard

  @doc """
  Runs `fun` (which returns `{:ok, _}` or `{:error, _}`) in a transaction
  and rolls it back with `{:error, :last_admin}` if, after it, no user holds
  the admin role while someone did before.

  The admin role row is locked (`FOR UPDATE`) for the whole transaction, so
  two concurrent calls (two admins removing each other) are serialized and
  the second one sees the first. Without an admin role nothing is checked.
  """
  def preserving_admins(fun) when is_function(fun, 0) do
    Repo.transact(fn ->
      slug = admin_role_slug()

      case Repo.one(from r in Role, where: r.slug == ^slug, lock: "FOR UPDATE", select: r.id) do
        nil ->
          fun.()

        admin_role_id ->
          admins_before = count_admins(admin_role_id)

          with {:ok, result} <- fun.() do
            if admins_before > 0 and count_admins(admin_role_id) == 0,
              do: {:error, :last_admin},
              else: {:ok, result}
          end
      end
    end)
  end

  # Users holding the admin role directly or through a role that inherits
  # from it (its descendants in the hierarchy).
  defp count_admins(admin_role_id) do
    descendants =
      from rr in RoleRole,
        join: f in "admin_family",
        on: rr.parent_role_id == f.id,
        select: %{id: rr.child_role_id}

    seed = from r in Role, where: r.id == ^admin_role_id, select: %{id: r.id}

    from(ur in UserRole,
      join: f in "admin_family",
      on: f.id == ur.role_id,
      select: count(ur.user_id, :distinct)
    )
    |> recursive_ctes(true)
    |> with_cte("admin_family", as: ^union(seed, ^descendants))
    |> Repo.one()
  end

  ## Query building blocks

  # `role_tree` holds the seed roles and all their ancestors. `UNION` (not
  # `UNION ALL`) drops rows that were already produced, so the recursion
  # ends even if `role_roles` contains a cycle.
  defp with_role_tree(query, seed) do
    ancestors =
      from rr in RoleRole,
        join: t in "role_tree",
        on: rr.child_role_id == t.id,
        select: %{id: rr.parent_role_id}

    query
    |> recursive_ctes(true)
    |> with_cte("role_tree", as: ^union(seed, ^ancestors))
  end

  defp user_seed(user_id),
    do: from(ur in UserRole, where: ur.user_id == ^user_id, select: %{id: ur.role_id})

  defp role_seed(role_id), do: from(r in Role, where: r.id == ^role_id, select: %{id: r.id})

  defp role_tree_permission_ids do
    from rp in RolePermission,
      join: t in "role_tree",
      on: t.id == rp.role_id,
      select: rp.permission_id
  end

  # Permissions granted to the user directly or through `role_tree`. The
  # caller adds `with_role_tree(user_seed(user_id))` to the outermost query.
  defp effective_permissions(user_id) do
    direct = from up in UserPermission, where: up.user_id == ^user_id, select: up.permission_id

    from p in Permission,
      where: p.id in subquery(direct) or p.id in subquery(role_tree_permission_ids())
  end

  ## Helpers

  defp check_actor(opts, allowed?) do
    case opts[:actor] do
      nil -> :ok
      actor -> if allowed?.(actor), do: :ok, else: {:error, :escalation}
    end
  end

  defp assigned_by(opts) do
    case {opts[:assigned_by], opts[:actor]} do
      {nil, %User{id: id}} -> id
      {nil, %Access{user_id: id}} -> id
      {assigned_by, _actor} -> assigned_by
    end
  end

  # Deletes the rows of `query`: `{:ok, :removed}` or `{:error, :not_found}`.
  # A single DELETE, so two concurrent removals cannot both "find" the row
  # and then fail on a stale entry: the loser deletes nothing.
  defp delete_one(query) do
    case Repo.delete_all(query) do
      {0, _} -> {:error, :not_found}
      {_count, _} -> {:ok, :removed}
    end
  end
end
