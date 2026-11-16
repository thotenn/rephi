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

  alias Rephi.Accounts
  alias Rephi.Authorization
  alias RephiWeb.PaginationJSON

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

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      page(:query, :integer, "Page, from 1 (default 1)", required: false)
      page_size(:query, :integer, "Entries per page (default 50, at most 100)", required: false)
    end

    response(200, "Success", Schema.ref(:UsersResponse))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden - requires users:view", Schema.ref(:ErrorResponse))
    response(422, "Invalid page or page_size", Schema.ref(:ValidationErrors))
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
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :integer, "User ID", required: true)
    end

    response(200, "Success", Schema.ref(:UserResponse))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden - requires users:view", Schema.ref(:ErrorResponse))
    response(404, "User not found", Schema.ref(:ErrorResponse))
  end

  def show(conn, %{"id" => id}) do
    with {:ok, user} <- Accounts.fetch_user(id) do
      render(conn, :show, user: Accounts.preload_grants(user))
    end
  end

  swagger_path :update do
    put("/api/users/{id}")
    summary("Change the email of a user")

    description(
      "Only the email can change. A password in the body is refused: users change their own with PUT /api/me/password. Requires users:edit, and holding every role of the user (or being an admin)."
    )

    produces("application/json")
    consumes("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :integer, "User ID", required: true)
      user(:body, Schema.ref(:UpdateUserRequest), "User attributes to update", required: true)
    end

    response(200, "Success", Schema.ref(:UserResponse))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))

    response(
      403,
      "Forbidden - requires users:edit, or the user holds roles the caller does not",
      Schema.ref(:ErrorResponse)
    )

    response(404, "User not found", Schema.ref(:ErrorResponse))
    response(422, "Validation errors", Schema.ref(:ValidationErrors))
  end

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
      "Requires users:delete, and holding every role of the user (or being an admin). Nobody can delete their own account, nor the last user holding the admin role."
    )

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :integer, "User ID", required: true)
    end

    response(204, "No Content - User deleted successfully")
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))

    response(
      403,
      "Forbidden - requires users:delete, or the user holds roles the caller does not",
      Schema.ref(:ErrorResponse)
    )

    response(404, "User not found", Schema.ref(:ErrorResponse))
    response(409, "Own account, or the last admin", Schema.ref(:ErrorResponse))
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
    summary("Get user roles")
    description("The roles assigned to the user (not the inherited ones). Requires users:view.")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :integer, "User ID", required: true)
    end

    response(200, "Success", Schema.ref(:UserRolesResponse))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden - requires users:view", Schema.ref(:ErrorResponse))
    response(404, "User not found", Schema.ref(:ErrorResponse))
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
    Map.merge(PaginationJSON.swagger_definitions(), %{
      User: %{
        type: :object,
        title: "User",
        description: "A user in the system",
        properties: %{
          id: %{type: :integer, description: "User ID"},
          email: %{type: :string, description: "User email address"},
          roles: %{
            type: :array,
            description: "Roles assigned to the user, by slug",
            items: Schema.ref(:SessionGrant)
          },
          permissions: %{
            type: :array,
            description: "Permissions granted to the user directly (not through roles), by slug",
            items: Schema.ref(:SessionGrant)
          },
          inserted_at: %{type: :string, format: :"date-time", description: "Creation timestamp"},
          updated_at: %{type: :string, format: :"date-time", description: "Last update timestamp"}
        },
        required: [:id, :email]
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
              email: "user@example.com",
              roles: [%{id: 1, name: "Administrator", slug: "admin"}],
              permissions: [],
              inserted_at: "2025-01-03T10:00:00Z",
              updated_at: "2025-01-03T10:00:00Z"
            }
          ],
          meta: %{page: 1, page_size: 50, total: 1, total_pages: 1}
        }
      },
      UserResponse: %{
        type: :object,
        title: "User Response",
        description: "Response containing a single user",
        properties: %{
          data: Schema.ref(:User)
        }
      },
      UpdateUserRequest: %{
        type: :object,
        title: "Update User Request",
        description: "Only the email can change",
        properties: %{
          email: %{type: :string, description: "User email address"}
        },
        required: [:email],
        example: %{
          email: "user@example.com"
        }
      },
      UserRolesResponse: %{
        type: :object,
        title: "User Roles Response",
        description: "Response containing user roles",
        properties: %{
          data: %{
            type: :array,
            items: %{
              type: :object,
              properties: %{
                id: %{type: :integer},
                name: %{type: :string},
                slug: %{type: :string},
                description: %{type: :string}
              }
            }
          }
        }
      }
    })
  end
end
