defmodule RephiWeb.UserController do
  @moduledoc """
  User management.

  ## Endpoints

    * `GET /api/users` - List users, paginated (`users:view`)
    * `GET /api/users/:id` - Get a user (`users:view`)
    * `GET /api/users/:id/roles` - The roles assigned to a user (`users:view`)
    * `PUT /api/users/:id` - Change the email of a user (`users:edit`)
    * `DELETE /api/users/:id` - Delete a user (`users:delete`)

  ## Rules

    * `PUT` only changes the email; the body may be flat or wrapped under
      `"user"`. A `password` in it is refused (`422`): users change their own
      password with `PUT /api/me/password`, nobody sets another user's.
    * `PUT` and `DELETE` on a user who holds a role the caller does not hold
      (assigned or inherited) answer `403`, unless the caller is an admin
      (`Rephi.Authorization.can_manage_user?/2`).
    * Nobody can delete their own account here (`409`), and the last user
      holding the admin role cannot be deleted (`409`).

  An `:id` that is not the id of an existing user (unknown, not a number, out
  of range) answers `404`. Lists accept `page` and `page_size` (see
  `Rephi.Pagination`).
  """

  use RephiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import RephiWeb.ApiSpec.Operations

  alias Rephi.Accounts
  alias Rephi.Authorization
  alias RephiWeb.Schemas

  action_fallback RephiWeb.FallbackController

  tags ["Users"]
  security bearer_auth()

  plug AuthorizationPlug,
       {:permission, "users:view"} when action in [:index, :show, :get_user_roles]

  plug AuthorizationPlug, {:permission, "users:edit"} when action in [:update]
  plug AuthorizationPlug, {:permission, "users:delete"} when action in [:delete]

  operation :index,
    summary: "List users",
    description:
      "One page of users, ordered by id, with the roles assigned to them and the permissions granted to them directly. Requires users:view.",
    parameters: page_params(),
    responses:
      responses([
        :unauthorized,
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
        no_content: "User deleted",
        forbidden:
          "Forbidden - requires users:delete, or the user holds roles the caller does not",
        not_found: "User not found",
        conflict: "The caller's own account, or the last user holding the admin role"
      ])

  def delete(conn, %{"id" => id}) do
    with {:ok, user} <- Accounts.fetch_user(id),
         :ok <- refuse_self(conn, user),
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
        ok: {"The roles of the user", Schemas.UserRolesResponse},
        forbidden: "Forbidden - requires users:view",
        not_found: "User not found"
      ])

  def get_user_roles(conn, %{"id" => id}) do
    with {:ok, user} <- Accounts.fetch_user(id) do
      render(conn, :roles, roles: Authorization.get_user_roles(user))
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

  defp refuse_self(conn, user) do
    if conn.assigns.current_user.id == user.id, do: {:error, :self_delete}, else: :ok
  end

  defp ensure_can_manage(conn, user) do
    if Authorization.can_manage_user?(current_access(conn), user),
      do: :ok,
      else: {:error, :outranked}
  end
end
