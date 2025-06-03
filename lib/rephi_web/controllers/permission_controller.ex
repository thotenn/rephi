defmodule RephiWeb.PermissionController do
  use RephiWeb, :controller

  alias Rephi.Authorization
  alias Rephi.Authorization.Permission

  action_fallback RephiWeb.FallbackController

  plug AuthorizationPlug, {:permission, "permissions:view"} when action in [:index, :show]
  plug AuthorizationPlug, {:permission, "permissions:create"} when action in [:create]
  plug AuthorizationPlug, {:permission, "permissions:edit"} when action in [:update]
  plug AuthorizationPlug, {:permission, "permissions:delete"} when action in [:delete]
  plug AuthorizationPlug, {:permission, "permissions:assign"} when action in [:assign_to_role, :remove_from_role]

  def index(conn, _params) do
    permissions = Authorization.list_permissions()
    render(conn, :index, permissions: permissions)
  end

  def show(conn, %{"id" => id}) do
    permission = Authorization.get_permission!(id)
    render(conn, :show, permission: permission)
  end

  def create(conn, %{"permission" => permission_params}) do
    with {:ok, %Permission{} = permission} <- Authorization.create_permission(permission_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/permissions/#{permission}")
      |> render(:show, permission: permission)
    end
  end

  def update(conn, %{"id" => id, "permission" => permission_params}) do
    permission = Authorization.get_permission!(id)

    with {:ok, %Permission{} = permission} <- Authorization.update_permission(permission, permission_params) do
      render(conn, :show, permission: permission)
    end
  end


  def delete(conn, %{"id" => id}) do
    permission = Authorization.get_permission!(id)

    with {:ok, %Permission{}} <- Authorization.delete_permission(permission) do
      send_resp(conn, :no_content, "")
    end
  end

  def assign_to_role(conn, %{"role_id" => role_id, "permission_id" => permission_id} = params) do
    role = Authorization.get_role!(role_id)
    permission = Authorization.get_permission!(permission_id)
    
    opts = %{
      assigned_by: conn.assigns.current_user.id,
      notes: params["notes"]
    }

    with {:ok, _} <- Authorization.assign_permission_to_role(role, permission, opts) do
      send_resp(conn, :created, "")
    end
  end

  def remove_from_role(conn, %{"role_id" => role_id, "permission_id" => permission_id}) do
    role = Authorization.get_role!(role_id)
    permission = Authorization.get_permission!(permission_id)

    with {:ok, _} <- Authorization.remove_permission_from_role(role, permission) do
      send_resp(conn, :no_content, "")
    end
  end

end