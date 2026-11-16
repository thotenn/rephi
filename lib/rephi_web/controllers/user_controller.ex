defmodule RephiWeb.UserController do
  @moduledoc """
  User management (`/api/users`). Only an admin may change a user holding a role
  the caller does not hold (`Rephi.Authorization.can_manage_user?/2`).
  """

  use RephiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import RephiWeb.ApiSpec.Operations

  alias OpenApiSpex.{Header, Schema}
  alias Rephi.Accounts
  alias Rephi.Authorization
  alias RephiWeb.Schemas

  action_fallback RephiWeb.FallbackController

  tags ["Users"]
  security bearer_auth()

  plug AuthorizationPlug,
       {:permission, "users:view"}
       when action in [:index, :show, :get_user_roles, :get_user_permissions]

  plug AuthorizationPlug, {:permission, "users:edit"} when action in [:update]
  plug AuthorizationPlug, {:permission, "users:delete"} when action in [:delete]
  plug AuthorizationPlug, {:permission, "users:reset_password"} when action in [:reset_password]

  operation :index,
    summary: "List users",
    description:
      "One page of users, ordered by id, with the roles assigned to them and the permissions granted to them directly. Requires users:view.",
    parameters: page_params(),
    responses:
      responses([
        :unauthorized,
        :password_settled,
        :invalid_page,
        ok: {"One page of users", Schemas.UsersResponse},
        forbidden: "Forbidden - requires users:view"
      ])

  def index(conn, params) do
    with {:ok, page} <- Accounts.paginate_users(params) do
      render(conn, :index, page: page)
    end
  end

  operation :show,
    summary: "Get a user",
    description: "A user with its assigned roles and direct permissions. Requires users:view.",
    parameters: [id_param(:id, "User ID")],
    responses:
      responses([
        :unauthorized,
        :password_settled,
        ok: {"The user", Schemas.UserResponse},
        forbidden: "Forbidden - requires users:view",
        not_found: "User not found"
      ])

  def show(conn, %{"id" => id}) do
    with {:ok, user} <- Accounts.fetch_user(id) do
      render(conn, :show, user: Accounts.preload_grants(user))
    end
  end

  operation :update,
    summary: "Change the email of a user",
    description:
      "Only the email can change; other attributes are ignored and a password is refused (422): users change their own with PUT /api/me/password. The attributes may also be wrapped under \"user\". PUT and PATCH behave the same. Requires users:edit, and holding every role of the user or being an admin.",
    parameters: [id_param(:id, "User ID")],
    request_body: body("The new email", Schemas.UpdateUserRequest),
    responses:
      responses([
        :unauthorized,
        :password_settled,
        :body_errors,
        ok: {"User updated", Schemas.UserResponse},
        forbidden: "Forbidden - requires users:edit, or the user holds roles the caller does not",
        not_found: "User not found",
        unprocessable_entity: "Invalid or taken email, or a password in the body"
      ])

  def update(conn, %{"id" => id}) do
    params = resource_params(conn, "user")

    with {:ok, user} <- Accounts.fetch_user(id),
         :ok <- ensure_can_manage(conn, user),
         :ok <- refuse_password(params),
         {:ok, user} <- Accounts.update_user(user, Map.take(params, ["email"])) do
      render(conn, :show, user: Accounts.preload_grants(user))
    end
  end

  operation :delete,
    summary: "Delete a user",
    description:
      "Revokes the user's tokens and closes its WebSocket connections. Requires users:delete, and holding every role of the user or being an admin.",
    parameters: [id_param(:id, "User ID")],
    responses:
      responses([
        :unauthorized,
        :password_settled,
        no_content: "User deleted",
        forbidden:
          "Forbidden - requires users:delete, or the user holds roles the caller does not",
        not_found: "User not found",
        conflict: "The caller's own account, or the last user holding the admin role"
      ])

  def delete(conn, %{"id" => id}) do
    with {:ok, user} <- Accounts.fetch_user(id),
         :ok <- refuse_self(conn, user, :self_delete),
         :ok <- ensure_can_manage(conn, user),
         {:ok, _user} <- Accounts.delete_user(user) do
      send_resp(conn, :no_content, "")
    end
  end

  operation :get_user_roles,
    summary: "List the roles of a user",
    description:
      "The roles assigned to the user (not the inherited ones), by slug. Not paginated. Requires users:view.",
    parameters: [id_param(:id, "User ID")],
    responses:
      responses([
        :unauthorized,
        :password_settled,
        ok: {"The roles of the user", Schemas.UserRolesResponse},
        forbidden: "Forbidden - requires users:view",
        not_found: "User not found"
      ])

  def get_user_roles(conn, %{"id" => id}) do
    with {:ok, user} <- Accounts.fetch_user(id) do
      render(conn, :roles, roles: Authorization.get_user_roles(user))
    end
  end

  operation :get_user_permissions,
    summary: "List the permissions of a user",
    description:
      "direct: the permissions granted to the user itself (the ones DELETE /api/users/{user_id}/permissions/{permission_id} revokes), with who granted them. effective: everything the user may do, each with where it comes from: direct (granted to the user itself) and roles (the roles that grant it, assigned to the user or inherited through the hierarchy). Both by slug. Not paginated. Requires users:view.",
    parameters: [id_param(:id, "User ID")],
    responses:
      responses([
        :unauthorized,
        :password_settled,
        ok: {"The permissions of the user", Schemas.UserPermissionsResponse},
        forbidden: "Forbidden - requires users:view",
        not_found: "User not found"
      ])

  def get_user_permissions(conn, %{"id" => id}) do
    with {:ok, user} <- Accounts.fetch_user(id) do
      render(conn, :permissions, sources: Authorization.get_user_permission_sources(user))
    end
  end

  operation :reset_password,
    summary: "Reset the password of a user",
    description:
      "Replaces the user's password with a random temporary one, returned once in this response (never stored in clear; cache-control: no-store). Every token of the user is revoked and its WebSocket connections are closed. The user signs in with the temporary password and must then set a new one with PUT /api/me/password: until then every other route but GET /api/me and POST /api/users/logout answers 403, and its session reports must_change_password: true. No body. Requires users:reset_password, and holding every role of the user or being an admin. Your own password is changed with PUT /api/me/password (409 here).",
    parameters: [id_param(:id, "User ID")],
    responses:
      responses([
        :unauthorized,
        :password_settled,
        ok:
          {"Password reset", Schemas.PasswordResetResponse,
           headers: %{
             "cache-control" => %Header{
               description: "no-store: the temporary password must not be cached",
               schema: %Schema{type: :string, enum: ["no-store"]}
             }
           }},
        forbidden:
          "Forbidden - requires users:reset_password, or the user holds roles the caller does not",
        not_found: "User not found",
        conflict: "The caller's own account"
      ])

  def reset_password(conn, %{"id" => id}) do
    with {:ok, user} <- Accounts.fetch_user(id),
         :ok <- refuse_self(conn, user, :self_password_reset),
         :ok <- ensure_can_manage(conn, user),
         {:ok, user, password} <- Accounts.reset_password(user) do
      conn
      |> put_resp_header("cache-control", "no-store")
      |> render(:password_reset, user: Accounts.preload_grants(user), password: password)
    end
  end

  defp refuse_password(params) do
    if Map.has_key?(params, "password") or Map.has_key?(params, "password_confirmation") do
      {:error,
       {%{}, %{password: :string}}
       |> Ecto.Changeset.change()
       |> Ecto.Changeset.add_error(
         :password,
         "cannot be changed here; users change their own with PUT /api/me/password"
       )}
    else
      :ok
    end
  end

  defp refuse_self(conn, user, reason) do
    if conn.assigns.current_user.id == user.id, do: {:error, reason}, else: :ok
  end

  defp ensure_can_manage(conn, user) do
    if Authorization.can_manage_user?(current_access(conn), user),
      do: :ok,
      else: {:error, :outranked}
  end
end
