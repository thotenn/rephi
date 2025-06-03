defmodule RephiWeb.UserJSON do
  @moduledoc """
  View module for rendering user data.

  This module handles the JSON rendering of user resources,
  including their associated roles and permissions.
  """

  alias Rephi.Accounts.User

  @doc """
  Renders a list of users.
  """
  def index(%{users: users}) do
    %{data: for(user <- users, do: data(user))}
  end

  @doc """
  Renders a single user.
  """
  def show(%{user: user}) do
    %{data: data(user)}
  end

  @doc """
  Renders user with authentication token.
  """
  def user_with_token(%{user: user, token: token}) do
    %{
      user: %{
        id: user.id,
        email: user.email
      },
      token: token
    }
  end

  @doc """
  Renders current user with roles and permissions.
  """
  def me_with_auth(%{user: user, roles: roles, permissions: permissions}) do
    %{
      user: %{
        id: user.id,
        email: user.email,
        roles: render_roles(roles),
        permissions: render_permissions(permissions)
      }
    }
  end

  defp data(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      roles: render_roles(user.roles || []),
      permissions: render_permissions(user.permissions || []),
      inserted_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end

  defp render_roles(roles) do
    for role <- roles do
      %{
        id: role.id,
        name: role.name,
        slug: role.slug
      }
    end
  end

  defp render_permissions(permissions) do
    for permission <- permissions do
      %{
        id: permission.id,
        name: permission.name,
        slug: permission.slug
      }
    end
  end
end