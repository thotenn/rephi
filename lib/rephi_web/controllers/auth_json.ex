defmodule RephiWeb.AuthJSON do
  @moduledoc """
  Renders the responses of `RephiWeb.AuthController`.

  Register, login, "me" and a password change all describe the signed-in user
  the same way (the roles assigned to it and its effective permissions, from
  its `Rephi.Authorization.Access`), so a client can build its session from
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

  defp user(%{user: user, access: access}) do
    %{
      id: user.id,
      email: user.email,
      must_change_password: user.must_change_password,
      roles: Enum.map(access.roles, &summary/1),
      permissions: Enum.map(access.permissions, &summary/1)
    }
  end

  defp summary(%{id: id, name: name, slug: slug}), do: %{id: id, name: name, slug: slug}
end
