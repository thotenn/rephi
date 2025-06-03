defmodule RephiWeb.Auth.AuthorizationPlug do
  @moduledoc """
  Plugs for handling authorization in controllers.
  """
  
  import Plug.Conn
  import Phoenix.Controller
  alias Rephi.Authorization

  @doc """
  Ensures the current user has the specified permission.
  
  ## Examples
  
      # In a controller
      plug RephiWeb.Auth.AuthorizationPlug, :require_permission, "users:edit"
  """
  def require_permission(conn, permission_slug) when is_binary(permission_slug) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> put_view(RephiWeb.ErrorJSON)
        |> render(:"401")
        |> halt()
      
      user ->
        if Authorization.can?(user, permission_slug) do
          conn
        else
          conn
          |> put_status(:forbidden)
          |> put_view(RephiWeb.ErrorJSON)
          |> render(:"403")
          |> halt()
        end
    end
  end

  @doc """
  Ensures the current user has the specified role.
  
  ## Examples
  
      # In a controller
      plug RephiWeb.Auth.AuthorizationPlug, :require_role, "admin"
  """
  def require_role(conn, role_slug) when is_binary(role_slug) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> put_view(RephiWeb.ErrorJSON)
        |> render(:"401")
        |> halt()
      
      user ->
        if Authorization.has_role?(user, role_slug) do
          conn
        else
          conn
          |> put_status(:forbidden)
          |> put_view(RephiWeb.ErrorJSON)
          |> render(:"403")
          |> halt()
        end
    end
  end

  @doc """
  Ensures the current user has any of the specified permissions.
  
  ## Examples
  
      # In a controller
      plug RephiWeb.Auth.AuthorizationPlug, :require_any_permission, ["users:edit", "users:create"]
  """
  def require_any_permission(conn, permission_slugs) when is_list(permission_slugs) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> put_view(RephiWeb.ErrorJSON)
        |> render(:"401")
        |> halt()
      
      user ->
        has_any = Enum.any?(permission_slugs, &Authorization.can?(user, &1))
        
        if has_any do
          conn
        else
          conn
          |> put_status(:forbidden)
          |> put_view(RephiWeb.ErrorJSON)
          |> render(:"403")
          |> halt()
        end
    end
  end

  @doc """
  Ensures the current user has all of the specified permissions.
  
  ## Examples
  
      # In a controller
      plug RephiWeb.Auth.AuthorizationPlug, :require_all_permissions, ["users:edit", "system:manage"]
  """
  def require_all_permissions(conn, permission_slugs) when is_list(permission_slugs) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> put_view(RephiWeb.ErrorJSON)
        |> render(:"401")
        |> halt()
      
      user ->
        has_all = Enum.all?(permission_slugs, &Authorization.can?(user, &1))
        
        if has_all do
          conn
        else
          conn
          |> put_status(:forbidden)
          |> put_view(RephiWeb.ErrorJSON)
          |> render(:"403")
          |> halt()
        end
    end
  end

  @doc """
  Plug to use in controllers for authorization.
  Call with :init_options set to {:permission, "permission:slug"} or {:role, "role_slug"}
  
  ## Examples
  
      # In a controller
      plug RephiWeb.Auth.AuthorizationPlug, {:permission, "users:edit"}
      plug RephiWeb.Auth.AuthorizationPlug, {:role, "admin"}
      plug RephiWeb.Auth.AuthorizationPlug, {:any_permission, ["users:edit", "users:create"]}
      plug RephiWeb.Auth.AuthorizationPlug, {:all_permissions, ["users:edit", "system:manage"]}
  """
  def init(opts), do: opts

  def call(conn, {:permission, permission_slug}) do
    require_permission(conn, permission_slug)
  end

  def call(conn, {:role, role_slug}) do
    require_role(conn, role_slug)
  end

  def call(conn, {:any_permission, permission_slugs}) do
    require_any_permission(conn, permission_slugs)
  end

  def call(conn, {:all_permissions, permission_slugs}) do
    require_all_permissions(conn, permission_slugs)
  end
end