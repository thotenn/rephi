defmodule RephiWeb.PermissionJSON do
  @moduledoc """
  Renders permissions and role-permission assignments.
  """

  alias Rephi.Authorization.{Permission, RolePermission}

  @doc """
  Renders a list of permissions.
  """
  def index(%{permissions: permissions}) do
    %{data: for(permission <- permissions, do: data(permission))}
  end

  @doc """
  Renders a single permission.
  """
  def show(%{permission: permission}) do
    %{data: data(permission)}
  end

  @doc """
  Renders the assignment of a permission to a role.
  """
  def assignment(%{role_permission: %RolePermission{} = role_permission}) do
    %{
      data: %{
        role_id: role_permission.role_id,
        permission_id: role_permission.permission_id,
        assigned_by: role_permission.assigned_by,
        notes: role_permission.notes,
        inserted_at: role_permission.inserted_at
      }
    }
  end

  defp data(%Permission{} = permission) do
    %{
      id: permission.id,
      name: permission.name,
      slug: permission.slug,
      description: permission.description,
      parent_id: permission.parent_id,
      inserted_at: permission.inserted_at,
      updated_at: permission.updated_at
    }
  end
end
