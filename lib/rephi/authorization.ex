defmodule Rephi.Authorization do
  @moduledoc """
  The Authorization context manages roles, permissions, and user authorization.
  """

  import Ecto.Query, warn: false
  alias Rephi.Repo
  alias Rephi.Accounts.{User, UserRole, UserPermission}
  alias Rephi.Authorization.{Role, Permission, RolePermission, RoleRole}

  # Role Management Functions

  @doc """
  Returns the list of roles.
  """
  def list_roles do
    Repo.all(Role)
  end

  @doc """
  Gets a single role.
  """
  def get_role!(id), do: Repo.get!(Role, id)
  def get_role(id), do: Repo.get(Role, id)

  @doc """
  Gets a role by slug.
  """
  def get_role_by_slug(slug) do
    Repo.get_by(Role, slug: slug)
  end

  @doc """
  Creates a role.
  """
  def create_role(attrs \\ %{}) do
    %Role{}
    |> Role.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a role.
  """
  def update_role(%Role{} = role, attrs) do
    role
    |> Role.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a role.
  """
  def delete_role(%Role{} = role) do
    Repo.delete(role)
  end

  # Permission Management Functions

  @doc """
  Returns the list of permissions.
  """
  def list_permissions do
    Repo.all(Permission)
  end

  @doc """
  Gets a single permission.
  """
  def get_permission!(id), do: Repo.get!(Permission, id)
  def get_permission(id), do: Repo.get(Permission, id)

  @doc """
  Gets a permission by slug.
  """
  def get_permission_by_slug(slug) do
    Repo.get_by(Permission, slug: slug)
  end

  @doc """
  Creates a permission.
  """
  def create_permission(attrs \\ %{}) do
    %Permission{}
    |> Permission.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a permission.
  """
  def update_permission(%Permission{} = permission, attrs) do
    permission
    |> Permission.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a permission.
  """
  def delete_permission(%Permission{} = permission) do
    Repo.delete(permission)
  end

  # User-Role Assignment Functions

  @doc """
  Assigns a role to a user.
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
  Removes a role from a user.
  """
  def remove_role_from_user(%User{} = user, %Role{} = role) do
    case Repo.get_by(UserRole, user_id: user.id, role_id: role.id) do
      nil -> {:error, :not_found}
      user_role -> Repo.delete(user_role)
    end
  end

  @doc """
  Gets all roles for a user.
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
  Checks if a user has a specific permission (directly or through roles).
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
  Checks if a user has a specific role.
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
  Gets all permissions for a user (direct + through roles).
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
  Flexible authorization check with various options.
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
  Checks if a role has a specific permission (directly or through inheritance).
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