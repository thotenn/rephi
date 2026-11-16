defmodule RephiWeb.UserController do
  @moduledoc """
  Controller for user management endpoints.

  All actions require authentication and the admin role.

  ## Endpoints

    * `GET /api/users` - List all users
    * `GET /api/users/:id` - Get a user
    * `PUT /api/users/:id` - Update a user (attributes flat or wrapped under `"user"`)
    * `DELETE /api/users/:id` - Delete a user
    * `GET /api/users/:id/roles` - List the roles of a user

  An `:id` that is not the id of an existing user (unknown, not a number, out
  of range) answers `404`.

  ## Permission Requirements

  All actions require authentication and admin role.
  """

  use RephiWeb, :controller
  use PhoenixSwagger

  alias Rephi.Accounts
  alias Rephi.Authorization

  action_fallback RephiWeb.FallbackController

  # Only users with admin role can access this endpoint
  plug AuthorizationPlug, {:role, "admin"}

  @doc """
  Lists all users in the system.

  Returns a list of all users with their roles and permissions.
  Only accessible by users with admin role.
  """
  swagger_path :index do
    get("/api/users")
    summary("List all users")

    description(
      "Returns a list of all users in the system with their roles and permissions. Requires admin role."
    )

    produces("application/json")
    security([%{Bearer: []}])

    response(200, "Success", Schema.ref(:UsersResponse))
    response(401, "Unauthorized - No authentication token")
    response(403, "Forbidden - User lacks admin role")
  end

  def index(conn, _params) do
    users = Accounts.list_users()
    render(conn, :index, users: users)
  end

  @doc """
  Shows a specific user by ID.

  Returns detailed information about a user including roles and permissions.
  Only accessible by users with admin role.
  """
  swagger_path :show do
    get("/api/users/{id}")
    summary("Get user details")
    description("Returns detailed information about a specific user. Requires admin role.")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "User ID", required: true)
    end

    response(200, "Success", Schema.ref(:UserResponse))
    response(401, "Unauthorized - No authentication token")
    response(403, "Forbidden - User lacks admin role")
    response(404, "User not found")
  end

  def show(conn, %{"id" => id}) do
    with {:ok, user} <- Accounts.fetch_user(id) do
      render(conn, :show, user: user)
    end
  end

  @doc """
  Updates a user.

  Allows updating user information. Only accessible by users with admin role.
  """
  swagger_path :update do
    put("/api/users/{id}")
    summary("Update user")
    description("Updates user information. Requires admin role.")
    produces("application/json")
    consumes("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "User ID", required: true)
      user(:body, Schema.ref(:UpdateUserRequest), "User attributes to update", required: true)
    end

    response(200, "Success", Schema.ref(:UserResponse))
    response(401, "Unauthorized - No authentication token")
    response(403, "Forbidden - User lacks admin role")
    response(404, "User not found")
    response(422, "Validation errors")
  end

  def update(conn, %{"id" => id}) do
    with {:ok, user} <- Accounts.fetch_user(id),
         {:ok, user} <- Accounts.update_user(user, resource_params(conn, "user")) do
      render(conn, :show, user: user)
    end
  end

  @doc """
  Deletes a user.

  Permanently removes a user from the system. Only accessible by users with admin role.
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/users/{id}")
    summary("Delete user")
    description("Permanently removes a user from the system. Requires admin role.")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "User ID", required: true)
    end

    response(204, "No Content - User deleted successfully")
    response(401, "Unauthorized - No authentication token")
    response(403, "Forbidden - User lacks admin role")
    response(404, "User not found")
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, user} <- Accounts.fetch_user(id),
         {:ok, _user} <- Accounts.delete_user(user) do
      send_resp(conn, :no_content, "")
    end
  end

  @doc """
  Gets roles for a specific user.

  Returns a list of roles assigned to the user. Only accessible by users with admin role.
  """
  swagger_path :get_user_roles do
    get("/api/users/{id}/roles")
    summary("Get user roles")
    description("Returns a list of roles assigned to the user. Requires admin role.")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "User ID", required: true)
    end

    response(200, "Success", Schema.ref(:UserRolesResponse))
    response(401, "Unauthorized - No authentication token")
    response(403, "Forbidden - User lacks admin role")
    response(404, "User not found")
  end

  def get_user_roles(conn, %{"id" => id}) do
    with {:ok, user} <- Accounts.fetch_user(id) do
      render(conn, :roles, roles: Authorization.get_user_roles(user))
    end
  end

  # Swagger definitions
  def swagger_definitions do
    %{
      User: %{
        type: :object,
        title: "User",
        description: "A user in the system",
        properties: %{
          id: %{type: :string, description: "User ID"},
          email: %{type: :string, description: "User email address"},
          roles: %{
            type: :array,
            description: "User roles",
            items: %{
              type: :object,
              properties: %{
                id: %{type: :string},
                name: %{type: :string},
                slug: %{type: :string}
              }
            }
          },
          permissions: %{
            type: :array,
            description: "Direct user permissions",
            items: %{
              type: :object,
              properties: %{
                id: %{type: :string},
                name: %{type: :string},
                slug: %{type: :string}
              }
            }
          },
          inserted_at: %{type: :string, format: :datetime, description: "Creation timestamp"},
          updated_at: %{type: :string, format: :datetime, description: "Last update timestamp"}
        },
        required: [:id, :email]
      },
      UsersResponse: %{
        type: :object,
        title: "Users Response",
        description: "Response containing list of users",
        properties: %{
          data: %{
            type: :array,
            items: Schema.ref(:User)
          }
        },
        example: %{
          data: [
            %{
              id: "123e4567-e89b-12d3-a456-426614174000",
              email: "user@example.com",
              roles: [
                %{id: "1", name: "Administrator", slug: "admin"}
              ],
              permissions: []
            }
          ]
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
        description: "Request body for updating a user",
        properties: %{
          email: %{type: :string, description: "User email address"}
        },
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
    }
  end
end
