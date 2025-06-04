defmodule RephiWeb.PermissionJSON do
  alias Rephi.Authorization.Permission

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