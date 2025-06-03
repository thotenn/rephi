defmodule Rephi.Authorization do
  @moduledoc """
  The Authorization context manages roles, permissions, and user authorization.

  This module implements a complete Role-Based Access Control (RBAC) system with 
  hierarchical roles and permissions. It provides functions for:

  - Role management (CRUD operations)
  - Permission management (CRUD operations) 
  - User-role assignments
  - User-permission assignments (direct)
  - Role-permission assignments
  - Role hierarchy management
  - Authorization checks

  ## Examples

      # Check if user has permission
      iex> Authorization.can?(user, "users:edit")
      true

      # Check if user has role
      iex> Authorization.has_role?(user, "admin")
      false

      # Get all user permissions (direct + inherited via roles)
      iex> Authorization.get_user_permissions(user)
      [%Permission{slug: "users:view"}, %Permission{slug: "users:create"}]

  ## Role Hierarchy

  Roles can inherit permissions from parent roles. For example:
  - `admin` role inherits from `manager` role
  - `manager` role inherits from `user` role
  - Users with `admin` role automatically have all `manager` and `user` permissions

  ## Permission Categories

  Permissions are organized by domain using colon notation:
  - `users:*` - User management permissions
  - `roles:*` - Role management permissions  
  - `permissions:*` - Permission management permissions
  - `system:*` - System administration permissions
  """

  import Ecto.Query, warn: false
  alias Rephi.Repo
  alias Rephi.Accounts.{User, UserRole, UserPermission}
  alias Rephi.Authorization.{Role, Permission, RolePermission, RoleRole}

  # Role Management Functions

  @doc """
  Returns the list of all roles in the system.

  ## Examples

      iex> Authorization.list_roles()
      [%Role{name: "Admin", slug: "admin"}, %Role{name: "User", slug: "user"}]

  """
  def list_roles do
    Repo.all(Role)
  end

  @doc """
  Gets a single role by ID, raising an exception if not found.

  ## Parameters

    * `id` - The role ID

  ## Examples

      iex> Authorization.get_role!(1)
      %Role{id: 1, name: "Admin"}

      iex> Authorization.get_role!(999)
      ** (Ecto.NoResultsError)

  """
  def get_role!(id), do: Repo.get!(Role, id)

  @doc """
  Gets a single role by ID, returning nil if not found.

  ## Parameters

    * `id` - The role ID

  ## Examples

      iex> Authorization.get_role(1)
      %Role{id: 1, name: "Admin"}

      iex> Authorization.get_role(999)
      nil

  """
  def get_role(id), do: Repo.get(Role, id)

  @doc """
  Gets a role by its unique slug identifier.

  ## Parameters

    * `slug` - The role slug (e.g., "admin", "user")

  ## Examples

      iex> Authorization.get_role_by_slug("admin")
      %Role{slug: "admin", name: "Administrator"}

      iex> Authorization.get_role_by_slug("nonexistent")
      nil

  """
  def get_role_by_slug(slug) do
    Repo.get_by(Role, slug: slug)
  end

  @doc """
  Creates a new role.

  ## Parameters

    * `attrs` - A map of role attributes

  ## Examples

      iex> Authorization.create_role(%{name: "Manager", slug: "manager"})
      {:ok, %Role{name: "Manager", slug: "manager"}}

      iex> Authorization.create_role(%{name: "", slug: ""})
      {:error, %Ecto.Changeset{}}

  """
  def create_role(attrs \\ %{}) do
    %Role{}
    |> Role.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing role.

  ## Parameters

    * `role` - The role struct to update
    * `attrs` - A map of attributes to update

  ## Examples

      iex> Authorization.update_role(role, %{name: "Senior Manager"})
      {:ok, %Role{name: "Senior Manager"}}

      iex> Authorization.update_role(role, %{slug: ""})
      {:error, %Ecto.Changeset{}}

  """
  def update_role(%Role{} = role, attrs) do
    role
    |> Role.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a role from the system.

  Also removes all associated user-role and role-permission assignments.

  ## Parameters

    * `role` - The role struct to delete

  ## Examples

      iex> Authorization.delete_role(role)
      {:ok, %Role{}}

      iex> Authorization.delete_role(invalid_role)
      {:error, %Ecto.Changeset{}}

  """
  def delete_role(%Role{} = role) do
    Repo.delete(role)
  end

  # Permission Management Functions

  @doc """
  Returns the list of all permissions in the system.

  ## Examples

      iex> Authorization.list_permissions()
      [
        %Permission{name: "View Users", slug: "users:view"},
        %Permission{name: "Create Users", slug: "users:create"}
      ]

  """
  def list_permissions do
    Repo.all(Permission)
  end

  @doc """
  Gets a single permission by ID, raising an exception if not found.

  ## Parameters

    * `id` - The permission ID

  ## Examples

      iex> Authorization.get_permission!(1)
      %Permission{id: 1, name: "View Users", slug: "users:view"}

      iex> Authorization.get_permission!(999)
      ** (Ecto.NoResultsError)

  """
  def get_permission!(id), do: Repo.get!(Permission, id)

  @doc """
  Gets a single permission by ID, returning nil if not found.

  ## Parameters

    * `id` - The permission ID

  ## Examples

      iex> Authorization.get_permission(1)
      %Permission{id: 1, name: "View Users"}

      iex> Authorization.get_permission(999)
      nil

  """
  def get_permission(id), do: Repo.get(Permission, id)

  @doc """
  Gets a permission by its unique slug identifier.

  ## Parameters

    * `slug` - The permission slug (e.g., "users:view", "roles:create")

  ## Examples

      iex> Authorization.get_permission_by_slug("users:view")
      %Permission{slug: "users:view", name: "View Users"}

      iex> Authorization.get_permission_by_slug("nonexistent")
      nil

  """
  def get_permission_by_slug(slug) do
    Repo.get_by(Permission, slug: slug)
  end

  @doc """
  Creates a new permission.

  ## Parameters

    * `attrs` - A map of permission attributes

  ## Examples

      iex> Authorization.create_permission(%{
      ...>   name: "Export Users", 
      ...>   slug: "users:export",
      ...>   description: "Export user data"
      ...> })
      {:ok, %Permission{name: "Export Users", slug: "users:export"}}

      iex> Authorization.create_permission(%{name: "", slug: ""})
      {:error, %Ecto.Changeset{}}

  """
  def create_permission(attrs \\ %{}) do
    %Permission{}
    |> Permission.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing permission.

  ## Parameters

    * `permission` - The permission struct to update
    * `attrs` - A map of attributes to update

  ## Examples

      iex> Authorization.update_permission(permission, %{
      ...>   description: "Updated description"
      ...> })
      {:ok, %Permission{description: "Updated description"}}

      iex> Authorization.update_permission(permission, %{slug: ""})
      {:error, %Ecto.Changeset{}}

  """
  def update_permission(%Permission{} = permission, attrs) do
    permission
    |> Permission.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a permission from the system.

  Also removes all associated role-permission and user-permission assignments.

  ## Parameters

    * `permission` - The permission struct to delete

  ## Examples

      iex> Authorization.delete_permission(permission)
      {:ok, %Permission{}}

      iex> Authorization.delete_permission(invalid_permission)
      {:error, %Ecto.Changeset{}}

  """
  def delete_permission(%Permission{} = permission) do
    Repo.delete(permission)
  end

  # User-Role Assignment Functions

  @doc """
  Assigns a role to a user.

  Creates a relationship between a user and a role, optionally with metadata
  about who assigned it and why.

  ## Parameters

    * `user` - The user struct
    * `role` - The role struct to assign
    * `opts` - Optional metadata (assigned_by, notes)

  ## Examples

      iex> Authorization.assign_role_to_user(user, admin_role)
      {:ok, %UserRole{}}

      iex> Authorization.assign_role_to_user(user, role, %{
      ...>   assigned_by: current_user.id,
      ...>   notes: "Promoted to admin"
      ...> })
      {:ok, %UserRole{notes: "Promoted to admin"}}

      iex> Authorization.assign_role_to_user(user, role)  # Already assigned
      {:error, %Ecto.Changeset{}}

  """
  def assign_role_to_user(%User{} = user, %Role{} = role, opts \\ %{}) do
    attrs = %{
      user_id: user.id,
      role_id: role.id,
      assigned_by: opts[:assigned_by],
      notes: opts[:notes]
    }

    %UserRole{}
    |> UserRole.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Removes a role assignment from a user.

  ## Parameters

    * `user` - The user struct
    * `role` - The role struct to remove

  ## Examples

      iex> Authorization.remove_role_from_user(user, admin_role)
      {:ok, %UserRole{}}

      iex> Authorization.remove_role_from_user(user, unassigned_role)
      {:error, :not_found}

  """
  def remove_role_from_user(%User{} = user, %Role{} = role) do
    case Repo.get_by(UserRole, user_id: user.id, role_id: role.id) do
      nil -> {:error, :not_found}
      user_role -> Repo.delete(user_role)
    end
  end

  @doc """
  Gets all roles directly assigned to a user.

  This does not include roles inherited through hierarchy.

  ## Parameters

    * `user` - The user struct

  ## Examples

      iex> Authorization.get_user_roles(user)
      [%Role{name: "Manager", slug: "manager"}]

  """
  def get_user_roles(%User{} = user) do
    user
    |> Repo.preload(:roles)
    |> Map.get(:roles)
  end

  # User-Permission Assignment Functions

  @doc """
  Assigns a permission directly to a user.
  """
  def assign_permission_to_user(%User{} = user, %Permission{} = permission, opts \\ %{}) do
    attrs = %{
      user_id: user.id,
      permission_id: permission.id,
      assigned_by: opts[:assigned_by],
      notes: opts[:notes]
    }

    %UserPermission{}
    |> UserPermission.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Removes a permission from a user.
  """
  def remove_permission_from_user(%User{} = user, %Permission{} = permission) do
    case Repo.get_by(UserPermission, user_id: user.id, permission_id: permission.id) do
      nil -> {:error, :not_found}
      user_permission -> Repo.delete(user_permission)
    end
  end

  # Role-Permission Assignment Functions

  @doc """
  Assigns a permission to a role.
  """
  def assign_permission_to_role(%Role{} = role, %Permission{} = permission, opts \\ %{}) do
    attrs = %{
      role_id: role.id,
      permission_id: permission.id,
      assigned_by: opts[:assigned_by],
      notes: opts[:notes]
    }

    %RolePermission{}
    |> RolePermission.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Removes a permission from a role.
  """
  def remove_permission_from_role(%Role{} = role, %Permission{} = permission) do
    case Repo.get_by(RolePermission, role_id: role.id, permission_id: permission.id) do
      nil -> {:error, :not_found}
      role_permission -> Repo.delete(role_permission)
    end
  end

  @doc """
  Gets all permissions for a role (including inherited permissions).
  """
  def get_role_permissions(%Role{} = role) do
    # Get direct permissions
    direct_permissions = 
      role
      |> Repo.preload(:permissions)
      |> Map.get(:permissions)

    # Get inherited permissions from parent roles
    inherited_permissions = get_inherited_permissions(role)

    # Combine and deduplicate
    (direct_permissions ++ inherited_permissions)
    |> Enum.uniq_by(& &1.id)
  end

  # Role Hierarchy Functions

  @doc """
  Assigns a parent role to a child role.
  """
  def assign_parent_role(%Role{} = child_role, %Role{} = parent_role) do
    attrs = %{
      child_role_id: child_role.id,
      parent_role_id: parent_role.id
    }

    %RoleRole{}
    |> RoleRole.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Removes a parent role from a child role.
  """
  def remove_parent_role(%Role{} = child_role, %Role{} = parent_role) do
    case Repo.get_by(RoleRole, child_role_id: child_role.id, parent_role_id: parent_role.id) do
      nil -> {:error, :not_found}
      role_role -> Repo.delete(role_role)
    end
  end

  # Authorization Check Functions

  @doc """
  Checks if a user has a specific permission.

  This function checks both direct permissions assigned to the user and 
  permissions inherited through roles. It supports hierarchical role inheritance.

  ## Parameters

    * `user` - The user struct to check permissions for
    * `permission` - Either a permission slug (string) or Permission struct

  ## Examples

      iex> Authorization.can?(user, "users:edit")
      true

      iex> Authorization.can?(user, permission_struct)
      false

      iex> Authorization.can?(nil, "users:edit")
      false

      iex> Authorization.can?(user, nil)
      false

  ## Permission Resolution Order

  1. Check direct user permissions
  2. Check permissions through assigned roles
  3. Check permissions through role hierarchy (parent roles)

  """
  def can?(%User{} = user, permission_slug) when is_binary(permission_slug) do
    permission = get_permission_by_slug(permission_slug)
    can?(user, permission)
  end

  def can?(%User{} = user, %Permission{} = permission) do
    has_direct_permission?(user, permission) or has_permission_through_role?(user, permission)
  end

  def can?(%User{} = _user, nil), do: false
  def can?(nil, _permission), do: false

  @doc """
  Checks if a user has a specific role assigned.

  This function only checks for direct role assignments, not role inheritance.

  ## Parameters

    * `user` - The user struct to check
    * `role` - Either a role slug (string) or Role struct

  ## Examples

      iex> Authorization.has_role?(user, "admin")
      true

      iex> Authorization.has_role?(user, admin_role)
      false

      iex> Authorization.has_role?(nil, "admin")
      false

      iex> Authorization.has_role?(user, nil)
      false

  """
  def has_role?(%User{} = user, role_slug) when is_binary(role_slug) do
    role = get_role_by_slug(role_slug)
    has_role?(user, role)
  end

  def has_role?(%User{} = user, %Role{} = role) do
    query = from ur in UserRole,
      where: ur.user_id == ^user.id and ur.role_id == ^role.id
    
    Repo.exists?(query)
  end

  def has_role?(%User{} = _user, nil), do: false
  def has_role?(nil, _role), do: false

  @doc """
  Gets all effective permissions for a user.

  Returns a deduplicated list of all permissions the user has access to,
  including both direct permissions and permissions inherited through roles
  and role hierarchy.

  ## Parameters

    * `user` - The user struct

  ## Examples

      iex> Authorization.get_user_permissions(user)
      [
        %Permission{slug: "users:view", name: "View Users"},
        %Permission{slug: "users:create", name: "Create Users"},
        %Permission{slug: "roles:view", name: "View Roles"}
      ]

  ## Permission Sources

  1. **Direct permissions**: Permissions assigned directly to the user
  2. **Role permissions**: Permissions assigned to user's roles
  3. **Inherited permissions**: Permissions from parent roles in hierarchy

  """
  def get_user_permissions(%User{} = user) do
    direct_permissions = get_direct_user_permissions(user)
    role_permissions = get_user_role_permissions(user)

    (direct_permissions ++ role_permissions)
    |> Enum.uniq_by(& &1.id)
  end

  # Private Helper Functions

  defp has_direct_permission?(%User{} = user, %Permission{} = permission) do
    query = from up in UserPermission,
      where: up.user_id == ^user.id and up.permission_id == ^permission.id

    Repo.exists?(query)
  end

  defp has_permission_through_role?(%User{} = user, %Permission{} = permission) do
    user_roles = get_user_roles(user)
    
    Enum.any?(user_roles, fn role ->
      role_permissions = get_role_permissions(role)
      Enum.any?(role_permissions, & &1.id == permission.id)
    end)
  end

  defp get_direct_user_permissions(%User{} = user) do
    query = from p in Permission,
      join: up in UserPermission,
      on: up.permission_id == p.id,
      where: up.user_id == ^user.id

    Repo.all(query)
  end

  defp get_user_role_permissions(%User{} = user) do
    user_roles = get_user_roles(user)
    
    user_roles
    |> Enum.flat_map(&get_role_permissions/1)
    |> Enum.uniq_by(& &1.id)
  end

  defp get_inherited_permissions(%Role{} = role) do
    parent_roles = get_parent_roles(role)
    
    parent_roles
    |> Enum.flat_map(&get_role_permissions/1)
    |> Enum.uniq_by(& &1.id)
  end

  defp get_parent_roles(%Role{} = role) do
    query = from r in Role,
      join: rr in RoleRole,
      on: rr.parent_role_id == r.id,
      where: rr.child_role_id == ^role.id

    parent_roles = Repo.all(query)
    
    # Recursively get parent roles of parent roles
    grandparent_roles = parent_roles
      |> Enum.flat_map(&get_parent_roles/1)
    
    (parent_roles ++ grandparent_roles)
    |> Enum.uniq_by(& &1.id)
  end

  @doc """
  Flexible authorization check with keyword options.

  This function provides a flexible interface for authorization checks
  using keyword arguments instead of positional parameters.

  ## Parameters

    * `opts` - Keyword list with authorization options

  ## Supported Options

    * `user: user, permission: "permission:slug"` - Check user permission
    * `user: user, role: "role_slug"` - Check user role

  ## Examples

      iex> Authorization.can_by?(user: user, permission: "users:edit")
      true

      iex> Authorization.can_by?(user: user, role: "admin")
      false

      iex> Authorization.can_by?(invalid: "option")
      false

  """
  def can_by?(opts) do
    cond do
      opts[:user] && opts[:permission] ->
        can?(opts[:user], opts[:permission])
      
      opts[:user] && opts[:role] ->
        has_role?(opts[:user], opts[:role])
      
      true ->
        false
    end
  end

  @doc """
  Checks if a role has a specific permission.

  This function checks both direct permissions assigned to the role and 
  permissions inherited through role hierarchy.

  ## Parameters

    * `role` - The role struct to check
    * `permission` - Either a permission slug (string) or Permission struct

  ## Examples

      iex> Authorization.role_has_permission?(admin_role, "users:delete")
      true

      iex> Authorization.role_has_permission?(user_role, delete_permission)
      false

      iex> Authorization.role_has_permission?(role, "nonexistent:permission")
      false

  ## Permission Resolution

  1. Check permissions directly assigned to the role
  2. Check permissions inherited from parent roles (recursive)

  """
  def role_has_permission?(%Role{} = role, %Permission{} = permission) do
    permissions = get_role_permissions(role)
    Enum.any?(permissions, & &1.id == permission.id)
  end

  def role_has_permission?(%Role{} = role, permission_slug) when is_binary(permission_slug) do
    case get_permission_by_slug(permission_slug) do
      nil -> false
      permission -> role_has_permission?(role, permission)
    end
  end
end