defmodule RephiWeb.Auth.AuthorizationHelpers do
  @moduledoc """
  Helper functions for authorization in controllers and views.
  """

  alias Rephi.Authorization

  @doc """
  Checks if the current user can perform an action.
  
  ## Examples
  
      # In a controller or view
      if can?(conn, "users:edit") do
        # Show edit button
      end
  """
  def can?(conn, permission_slug) do
    case conn.assigns[:current_user] do
      nil -> false
      user -> Authorization.can?(user, permission_slug)
    end
  end

  @doc """
  Checks if the current user has a role.
  
  ## Examples
  
      # In a controller or view
      if has_role?(conn, "admin") do
        # Show admin panel
      end
  """
  def has_role?(conn, role_slug) do
    case conn.assigns[:current_user] do
      nil -> false
      user -> Authorization.has_role?(user, role_slug)
    end
  end

  @doc """
  Checks if the current user has any of the given permissions.
  """
  def can_any?(conn, permission_slugs) when is_list(permission_slugs) do
    case conn.assigns[:current_user] do
      nil -> false
      user -> Enum.any?(permission_slugs, &Authorization.can?(user, &1))
    end
  end

  @doc """
  Checks if the current user has all of the given permissions.
  """
  def can_all?(conn, permission_slugs) when is_list(permission_slugs) do
    case conn.assigns[:current_user] do
      nil -> false
      user -> Enum.all?(permission_slugs, &Authorization.can?(user, &1))
    end
  end

  @doc """
  Gets the current user's roles.
  """
  def current_user_roles(conn) do
    case conn.assigns[:current_user] do
      nil -> []
      user -> Authorization.get_user_roles(user)
    end
  end

  @doc """
  Gets the current user's permissions.
  """
  def current_user_permissions(conn) do
    case conn.assigns[:current_user] do
      nil -> []
      user -> Authorization.get_user_permissions(user)
    end
  end

  @doc """
  Returns the current user or nil.
  """
  def current_user(conn) do
    conn.assigns[:current_user]
  end

  @doc """
  Authorize action with flexible options.
  
  ## Examples
  
      authorize(conn, permission: "users:edit")
      authorize(conn, role: "admin")
      authorize(conn, any_permission: ["users:edit", "users:create"])
  """
  def authorize(conn, opts) do
    cond do
      opts[:permission] ->
        can?(conn, opts[:permission])
      
      opts[:role] ->
        has_role?(conn, opts[:role])
      
      opts[:any_permission] ->
        can_any?(conn, opts[:any_permission])
      
      opts[:all_permissions] ->
        can_all?(conn, opts[:all_permissions])
      
      true ->
        false
    end
  end
end