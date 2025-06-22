defmodule RephiWeb.Auth.AuthorizationHelpers do
  @moduledoc """
  Helper functions for authorization checks in controllers and views.

  These helpers provide a convenient way to check user permissions and roles
  within controller actions and view templates. They automatically handle
  cases where no user is authenticated.

  ## Usage in Controllers

      defmodule MyAppWeb.UserController do
        use MyAppWeb, :controller  # Automatically imports these helpers

        def show(conn, %{"id" => id}) do
          if can?(conn, "users:view") do
            # User can view users
            user = Accounts.get_user!(id)
            render(conn, :show, user: user)
          else
            # Handle unauthorized access
            conn |> put_status(:forbidden) |> json(%{error: "Forbidden"})
          end
        end
      end

  ## Usage in Views/Templates

      # In a template (EEx)
      <%= if can?(@conn, "users:edit") do %>
        <button>Edit User</button>
      <% end %>

      <%= if has_role?(@conn, "admin") do %>
        <div class="admin-panel">Admin Tools</div>
      <% end %>

  ## Safe Defaults

  All functions return `false` when no user is authenticated, making them
  safe to use without additional nil checks.

  """

  alias Rephi.Authorization

  @doc """
  Checks if the current user has a specific permission.

  Returns `false` if no user is authenticated or if the user lacks the permission.

  ## Parameters

    * `conn` - The Plug.Conn struct containing user information
    * `permission_slug` - The permission slug to check (e.g., "users:edit")

  ## Examples

      # In a controller action
      if can?(conn, "users:edit") do
        # User can edit users
      end

      # In a view template
      <%= if can?(@conn, "roles:create") do %>
        <a href="/roles/new">Create Role</a>
      <% end %>

  ## Returns

    * `true` - User is authenticated and has the permission
    * `false` - User is not authenticated or lacks the permission

  """
  def can?(conn, permission_slug) do
    case conn.assigns[:current_user] do
      nil -> false
      user -> Authorization.can?(user, permission_slug)
    end
  end

  @doc """
  Checks if the current user has a specific role.

  Returns `false` if no user is authenticated or if the user doesn't have the role.

  ## Parameters

    * `conn` - The Plug.Conn struct containing user information
    * `role_slug` - The role slug to check (e.g., "admin", "manager")

  ## Examples

      # In a controller action
      if has_role?(conn, "admin") do
        # User is an admin
      end

      # In a view template
      <%= if has_role?(@conn, "manager") do %>
        <div class="manager-tools">Manager Dashboard</div>
      <% end %>

  ## Returns

    * `true` - User is authenticated and has the role
    * `false` - User is not authenticated or doesn't have the role

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
