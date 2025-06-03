defmodule RephiWeb.RoleController do
  use RephiWeb, :controller

  alias Rephi.Authorization
  alias Rephi.Authorization.Role

  action_fallback RephiWeb.FallbackController

  plug AuthorizationPlug, {:permission, "roles:view"} when action in [:index, :show]
  plug AuthorizationPlug, {:permission, "roles:create"} when action in [:create]
  plug AuthorizationPlug, {:permission, "roles:edit"} when action in [:update]
  plug AuthorizationPlug, {:permission, "roles:delete"} when action in [:delete]
  plug AuthorizationPlug, {:permission, "roles:assign"} when action in [:assign_to_user, :remove_from_user]

  def index(conn, _params) do
    roles = Authorization.list_roles()
    render(conn, :index, roles: roles)
  end

  def show(conn, %{"id" => id}) do
    role = Authorization.get_role!(id)
    permissions = Authorization.get_role_permissions(role)
    
    render(conn, :show, role: role, permissions: permissions)
  end

  def create(conn, %{"role" => role_params}) do
    with {:ok, %Role{} = role} <- Authorization.create_role(role_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/roles/#{role}")
      |> render(:show, role: role, permissions: [])
    end
  end

  def update(conn, %{"id" => id, "role" => role_params}) do
    role = Authorization.get_role!(id)

    with {:ok, %Role{} = role} <- Authorization.update_role(role, role_params) do
      permissions = Authorization.get_role_permissions(role)
      render(conn, :show, role: role, permissions: permissions)
    end
  end


  def delete(conn, %{"id" => id}) do
    role = Authorization.get_role!(id)

    with {:ok, %Role{}} <- Authorization.delete_role(role) do
      send_resp(conn, :no_content, "")
    end
  end

  def assign_to_user(conn, %{"user_id" => user_id, "role_id" => role_id} = params) do
    user = Rephi.Accounts.get_user!(user_id)
    role = Authorization.get_role!(role_id)
    
    opts = %{
      assigned_by: conn.assigns.current_user.id,
      notes: params["notes"]
    }

    with {:ok, _} <- Authorization.assign_role_to_user(user, role, opts) do
      send_resp(conn, :created, "")
    end
  end

  def remove_from_user(conn, %{"user_id" => user_id, "role_id" => role_id}) do
    user = Rephi.Accounts.get_user!(user_id)
    role = Authorization.get_role!(role_id)

    with {:ok, _} <- Authorization.remove_role_from_user(user, role) do
      send_resp(conn, :no_content, "")
    end
  end

end