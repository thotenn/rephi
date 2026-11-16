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
  use PhoenixSwagger

  import RephiWeb.Swagger

  alias PhoenixSwagger.Schema
  alias Rephi.Accounts
  alias Rephi.Authorization

  action_fallback RephiWeb.FallbackController

  plug AuthorizationPlug,
       {:permission, "users:view"} when action in [:index, :show, :get_user_roles]

  plug AuthorizationPlug, {:permission, "users:edit"} when action in [:update]
  plug AuthorizationPlug, {:permission, "users:delete"} when action in [:delete]

  swagger_path :index do
    get("/api/users")
    summary("List users")

    description(
      "One page of users, ordered by id, with the roles assigned to them and the permissions granted to them directly. Requires users:view."
    )

    tag("Users")
    produces("application/json")
    bearer_auth()
    page_params()
    response(200, "One page of users", Schema.ref(:UsersResponse))
    error_response(403, "Forbidden - requires users:view")
  end

  def index(conn, params) do
    with {:ok, page} <- Accounts.paginate_users(params) do
      render(conn, :index, page: page)
    end
  end

  swagger_path :show do
    get("/api/users/{id}")
    summary("Get a user")
    description("A user with its assigned roles and direct permissions. Requires users:view.")
    tag("Users")
    produces("application/json")
    bearer_auth()
    id_param(:id, "User ID")
    response(200, "The user", Schema.ref(:UserResponse))
    error_response(403, "Forbidden - requires users:view")
    error_response(404, "User not found")
  end

  def show(conn, %{"id" => id}) do
    with {:ok, user} <- Accounts.fetch_user(id) do
      render(conn, :show, user: Accounts.preload_grants(user))
    end
  end

  swagger_path :update do
    summary("Change the email of a user")

    description(
      "Only the email can change; other attributes are ignored and a password is refused (422): users change their own with PUT /api/me/password. The attributes may also be wrapped under \"user\". PUT and PATCH behave the same. Requires users:edit, and holding every role of the user or being an admin."
    )

    tag("Users")
    consumes("application/json")
    produces("application/json")
    bearer_auth()
    id_param(:id, "User ID")

    parameters do
      body(:body, Schema.ref(:UpdateUserRequest), "The new email", required: true)
    end

    response(200, "User updated", Schema.ref(:UserResponse))
    body_errors()

    error_response(
      403,
      "Forbidden - requires users:edit, or the user holds roles the caller does not"
    )

    error_response(404, "User not found")
    validation_response("Invalid or taken email, or a password in the body")
  end

  defoverridable swagger_path_update: 1
  def swagger_path_update(route), do: route |> super() |> operation_per_verb()

  def update(conn, %{"id" => id}) do
    params = resource_params(conn, "user")

    with {:ok, user} <- Accounts.fetch_user(id),
         :ok <- ensure_can_manage(conn, user),
         :ok <- refuse_password(params),
         {:ok, user} <- Accounts.update_user(user, Map.take(params, ["email"])) do
      render(conn, :show, user: Accounts.preload_grants(user))
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/users/{id}")
    summary("Delete a user")

    description(
      "Revokes the user's tokens and closes its WebSocket connections. Requires users:delete, and holding every role of the user or being an admin."
    )

    tag("Users")
    produces("application/json")
    bearer_auth()
    id_param(:id, "User ID")
    response(204, "User deleted")

    error_response(
      403,
      "Forbidden - requires users:delete, or the user holds roles the caller does not"
    )

    error_response(404, "User not found")
    error_response(409, "The caller's own account, or the last user holding the admin role")
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, user} <- Accounts.fetch_user(id),
         :ok <- refuse_self(conn, user),
         :ok <- ensure_can_manage(conn, user),
         {:ok, _user} <- Accounts.delete_user(user) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :get_user_roles do
    get("/api/users/{id}/roles")
    summary("List the roles of a user")

    description(
      "The roles assigned to the user (not the inherited ones), by slug. Not paginated. Requires users:view."
    )

    tag("Users")
    produces("application/json")
    bearer_auth()
    id_param(:id, "User ID")
    response(200, "The roles of the user", Schema.ref(:UserRolesResponse))
    error_response(403, "Forbidden - requires users:view")
    error_response(404, "User not found")
  end

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

  # Swagger definitions
  def swagger_definitions do
    RephiWeb.Swagger.definitions(%{
      User: %{
        type: :object,
        title: "User",
        properties: %{
          id: %{type: :integer},
          email: %{type: :string},
          roles: %{
            type: :array,
            description: "Roles assigned to the user (not the inherited ones), by slug",
            items: Schema.ref(:Grant)
          },
          permissions: %{
            type: :array,
            description: "Permissions granted to the user directly (not through roles), by slug",
            items: Schema.ref(:Grant)
          },
          inserted_at: %{type: :string, format: :"date-time"},
          updated_at: %{type: :string, format: :"date-time"}
        },
        required: [:id, :email, :roles, :permissions, :inserted_at, :updated_at]
      },
      UsersResponse: %{
        type: :object,
        title: "Users Response",
        description: "One page of users",
        properties: %{
          data: %{type: :array, items: Schema.ref(:User)},
          meta: Schema.ref(:PageMeta)
        },
        required: [:data, :meta],
        example: %{
          data: [
            %{
              id: 1,
              email: "admin@example.com",
              roles: [%{id: 1, name: "Administrator", slug: "admin"}],
              permissions: [],
              inserted_at: "2026-01-03T10:00:00Z",
              updated_at: "2026-01-03T10:00:00Z"
            }
          ],
          meta: %{page: 1, page_size: 50, total: 1, total_pages: 1}
        }
      },
      UserResponse: %{
        type: :object,
        title: "User Response",
        description: "A single user",
        properties: %{
          data: Schema.ref(:User)
        },
        required: [:data]
      },
      UpdateUserRequest: %{
        type: :object,
        title: "Update User Request",
        description: "Only the email can change; without it nothing changes",
        properties: %{
          email: %{type: :string, format: :email, maxLength: 160}
        },
        example: %{email: "someone@example.com"}
      },
      UserRolesResponse: %{
        type: :object,
        title: "User Roles Response",
        description: "The roles assigned to a user",
        properties: %{
          data: %{type: :array, items: Schema.ref(:GrantWithDescription)}
        },
        required: [:data]
      }
    })
  end
end
