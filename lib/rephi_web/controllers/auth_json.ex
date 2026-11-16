defmodule RephiWeb.AuthJSON do
  @moduledoc """
  Renders the responses of `RephiWeb.AuthController`.

  Register, login and "me" all describe the signed-in user the same way (with
  its roles and effective permissions), so a client can build its session from
  any of them.
  """

  @doc """
  Renders a new session: the user plus the token to authenticate with.
  """
  def session(%{token: token} = assigns) do
    %{data: %{user: user(assigns), token: token}}
  end

  @doc """
  Renders the signed-in user.
  """
  def me(assigns) do
    %{data: %{user: user(assigns)}}
  end

  defp user(%{user: user, roles: roles, permissions: permissions}) do
    %{
      id: user.id,
      email: user.email,
      roles: Enum.map(roles, &summary/1),
      permissions: Enum.map(permissions, &summary/1)
    }
  end

  defp summary(%{id: id, name: name, slug: slug}), do: %{id: id, name: name, slug: slug}
end
