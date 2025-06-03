defmodule RephiWeb.UserView do
  @moduledoc """
  View module for rendering user-related JSON responses.
  Provides consistent user data formatting across the application.
  """

  def render("user.json", %{user: user}) do
    %{
      id: user.id,
      email: user.email
    }
  end

  def render("user_with_token.json", %{user: user, token: token}) do
    %{
      user: render("user.json", %{user: user}),
      token: token
    }
  end

  def render("me.json", %{user: user}) do
    %{
      user: render("user.json", %{user: user})
    }
  end

  def render("me_with_auth.json", %{user: user, roles: roles, permissions: permissions}) do
    %{
      user: render("user.json", %{user: user}),
      roles: Enum.map(roles, &render_role/1),
      permissions: Enum.map(permissions, &render_permission/1)
    }
  end

  defp render_role(role) do
    %{
      id: role.id,
      name: role.name,
      slug: role.slug
    }
  end

  defp render_permission(permission) do
    %{
      id: permission.id,
      name: permission.name,
      slug: permission.slug
    }
  end
end
