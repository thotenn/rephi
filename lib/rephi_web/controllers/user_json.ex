defmodule RephiWeb.UserJSON do
  @moduledoc """
  Renders users with their assigned roles and direct permissions
  (`Rephi.Accounts.preload_grants/1`), not their effective rights.
  """

  alias Rephi.Accounts.User
  alias RephiWeb.PaginationJSON

  @doc """
  Renders a page of users: `{"data": [...], "meta": {...}}`.
  """
  def index(%{page: page}), do: PaginationJSON.render(page, &data/1)

  @doc """
  Renders a single user.
  """
  def show(%{user: user}) do
    %{data: data(user)}
  end

  @doc """
  Renders the direct permissions of a user and the effective ones with their source.
  """
  def permissions(%{sources: %{direct: direct, effective: effective}}) do
    %{
      data: %{
        direct:
          for grant <- direct do
            grant.permission
            |> permission_data()
            |> Map.merge(%{
              assigned_by: grant.assigned_by,
              notes: grant.notes,
              granted_at: grant.inserted_at
            })
          end,
        effective:
          for entry <- effective do
            entry.permission
            |> permission_data()
            |> Map.merge(%{direct: entry.direct, roles: Enum.map(entry.roles, &summary/1)})
          end
      }
    }
  end

  @doc """
  Renders a reset password: the user and its temporary password.
  """
  def password_reset(%{user: user, password: password}) do
    %{data: %{user: data(user), temporary_password: password}}
  end

  @doc """
  Renders user roles.
  """
  def roles(%{roles: roles}) do
    %{data: for(role <- roles, do: role_data(role))}
  end

  defp data(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      must_change_password: user.must_change_password,
      roles: grants(user.roles),
      permissions: grants(user.permissions),
      inserted_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end

  defp role_data(role) do
    %{
      id: role.id,
      name: role.name,
      slug: role.slug,
      description: role.description
    }
  end

  defp permission_data(permission) do
    %{
      id: permission.id,
      name: permission.name,
      slug: permission.slug,
      description: permission.description
    }
  end

  defp summary(%{id: id, name: name, slug: slug}), do: %{id: id, name: name, slug: slug}

  defp grants(grants) when is_list(grants) do
    for grant <- grants, do: %{id: grant.id, name: grant.name, slug: grant.slug}
  end

  defp grants(%Ecto.Association.NotLoaded{}), do: []
end
