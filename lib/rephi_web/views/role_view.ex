defmodule RephiWeb.RoleJSON do
  alias Rephi.Authorization.Role

  @doc """
  Renders a list of roles.
  """
  def index(%{roles: roles}) do
    %{data: for(role <- roles, do: data(role))}
  end

  @doc """
  Renders a single role.
  """
  def show(%{role: role, permissions: permissions}) do
    %{data: data(role, permissions)}
  end

  @doc """
  Renders role permissions.
  """
  def permissions(%{permissions: permissions}) do
    %{data: render_permissions(permissions)}
  end

  defp data(%Role{} = role) do
    %{
      id: role.id,
      name: role.name,
      slug: role.slug,
      description: role.description,
      inserted_at: role.inserted_at,
      updated_at: role.updated_at
    }
  end

  defp data(%Role{} = role, permissions) do
    role
    |> data()
    |> Map.put(:permissions, render_permissions(permissions))
  end

  defp render_permissions(permissions) do
    for permission <- permissions do
      %{
        id: permission.id,
        name: permission.name,
        slug: permission.slug,
        description: permission.description
      }
    end
  end
end
