defmodule RephiWeb.RoleJSON do
  @moduledoc """
  Renders roles, their permissions and user-role assignments.

  The permissions of a role come from
  `Rephi.Authorization.get_role_permission_sources/1`: the ones assigned to
  the role itself, and the ones it only inherits from its parent roles.
  """

  alias Rephi.Authorization.{Role, RoleRole, UserRole}
  alias RephiWeb.PaginationJSON

  @doc """
  Renders a page of roles: `{"data": [...], "meta": {...}}`.
  """
  def index(%{page: page}), do: PaginationJSON.render(page, &data/1)

  @doc """
  Renders a role with `permissions` (assigned to it) and
  `inherited_permissions` (inherited only, each with `inherited_from`).
  """
  def show(%{role: role, sources: %{direct: direct, inherited: inherited}}) do
    %{
      data:
        role
        |> data()
        |> Map.put(:permissions, Enum.map(direct, &permission/1))
        |> Map.put(:inherited_permissions, Enum.map(inherited, &inherited_permission/1))
    }
  end

  @doc """
  Renders every permission a role grants, each flagged `inherited` (not
  assigned to the role) with the roles it is `inherited_from`, by slug.
  """
  def permissions(%{sources: %{direct: direct, inherited: inherited}}) do
    direct = Enum.map(direct, &Map.merge(permission(&1), %{inherited: false, inherited_from: []}))
    inherited = Enum.map(inherited, &Map.put(inherited_permission(&1), :inherited, true))

    %{data: Enum.sort_by(direct ++ inherited, & &1.slug)}
  end

  @doc """
  Renders the assignment of a role to a user.
  """
  def assignment(%{user_role: %UserRole{} = user_role}) do
    %{
      data: %{
        user_id: user_role.user_id,
        role_id: user_role.role_id,
        assigned_by: user_role.assigned_by,
        notes: user_role.notes,
        inserted_at: user_role.inserted_at
      }
    }
  end

  @doc """
  Renders the parents or the children of a role, each with its link.
  """
  def links(%{links: links}) do
    %{
      data:
        for {%Role{} = role, %RoleRole{} = link} <- links do
          %{
            id: role.id,
            name: role.name,
            slug: role.slug,
            description: role.description,
            is_system: role.is_system,
            system_link: link.is_system,
            assigned_by: link.assigned_by,
            notes: link.notes,
            linked_at: link.inserted_at
          }
        end
    }
  end

  @doc """
  Renders a new link of the hierarchy: `role_id` inherits from `parent_id`.
  """
  def parent_assignment(%{link: %RoleRole{} = link}) do
    %{
      data: %{
        role_id: link.child_role_id,
        parent_id: link.parent_role_id,
        is_system: link.is_system,
        assigned_by: link.assigned_by,
        notes: link.notes,
        inserted_at: link.inserted_at
      }
    }
  end

  defp data(%Role{} = role) do
    %{
      id: role.id,
      name: role.name,
      slug: role.slug,
      description: role.description,
      is_system: role.is_system,
      inserted_at: role.inserted_at,
      updated_at: role.updated_at
    }
  end

  defp permission(permission) do
    %{
      id: permission.id,
      name: permission.name,
      slug: permission.slug,
      description: permission.description
    }
  end

  defp inherited_permission({permission, sources}) do
    permission
    |> permission()
    |> Map.put(:inherited_from, Enum.map(sources, &Map.take(&1, [:id, :name, :slug])))
  end
end
