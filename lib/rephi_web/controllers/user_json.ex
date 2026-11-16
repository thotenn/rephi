defmodule RephiWeb.UserJSON do
  @moduledoc """
  Renders users: the roles assigned to them and the permissions granted to
  them directly (`Rephi.Accounts.preload_grants/1`). What a user may do
  overall is not part of this view; the signed-in user gets it from
  `GET /api/me`.
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
  Renders user roles.
  """
  def roles(%{roles: roles}) do
    %{data: for(role <- roles, do: role_data(role))}
  end

  defp data(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
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

  defp grants(grants) when is_list(grants) do
    for grant <- grants, do: %{id: grant.id, name: grant.name, slug: grant.slug}
  end

  # Not loaded: render nothing rather than guess.
  defp grants(%Ecto.Association.NotLoaded{}), do: []
end
