defmodule RephiWeb.UserController do
  @moduledoc """
  User management.

  ## Endpoints

    * `GET /api/users` - List users, paginated (`users:view`)
    * `GET /api/users/:id` - Get a user (`users:view`)
    * `GET /api/users/:id/roles` - The roles assigned to a user (`users:view`)
    * `GET /api/users/:id/permissions` - Direct and effective permissions (`users:view`)
    * `PUT /api/users/:id` - Change the email of a user (`users:edit`)
    * `DELETE /api/users/:id` - Delete a user (`users:delete`)
    * `POST /api/users/:id/password` - Reset another user's password
      (`users:reset_password`)

  ## Rules

    * `PUT` only changes the email; the body may be flat or wrapped under
      `"user"`. A `password` in it is refused (`422`): users change their own
      password with `PUT /api/me/password`; an administrator resets someone
      else's with `POST /api/users/:id/password`.
    * `PUT`, `DELETE` and the password reset on a user who holds a role the
      caller does not hold (assigned or inherited) answer `403`, unless the
      caller is an admin (`Rephi.Authorization.can_manage_user?/2`).
    * Nobody can delete their own account (`409`) nor reset their own
      password (`409`) here, and the last user holding the admin role cannot
      be deleted (`409`).

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
       {:permission, "users:view"}
       when action in [:index, :show, :get_user_roles, :get_user_permissions]

  plug AuthorizationPlug, {:permission, "users:edit"} when action in [:update]
  plug AuthorizationPlug, {:permission, "users:delete"} when action in [:delete]
  plug AuthorizationPlug, {:permission, "users:reset_password"} when action in [:reset_password]

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
         :ok <- refuse_self(conn, user, :self_delete),
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

  swagger_path :get_user_permissions do
    get("/api/users/{id}/permissions")
    summary("List the permissions of a user")

    description(
      "direct: the permissions granted to the user itself (the ones DELETE /api/users/{user_id}/permissions/{permission_id} revokes), with who granted them. effective: everything the user may do, each with where it comes from: direct (granted to the user itself) and roles (the roles that grant it, assigned to the user or inherited through the hierarchy). Both by slug. Not paginated. Requires users:view."
    )

    tag("Users")
    produces("application/json")
    bearer_auth()
    id_param(:id, "User ID")
    response(200, "The permissions of the user", Schema.ref(:UserPermissionsResponse))
    error_response(403, "Forbidden - requires users:view")
    error_response(404, "User not found")
  end

  def get_user_permissions(conn, %{"id" => id}) do
    with {:ok, user} <- Accounts.fetch_user(id) do
      render(conn, :permissions, sources: Authorization.get_user_permission_sources(user))
    end
  end

  swagger_path :reset_password do
    post("/api/users/{id}/password")
    summary("Reset the password of a user")

    description(
      "Replaces the user's password with a random temporary one, returned once in this response (never stored in clear; cache-control: no-store). Every token of the user is revoked and its WebSocket connections are closed. The user signs in with the temporary password and must then set a new one with PUT /api/me/password: until then every other route but GET /api/me and POST /api/users/logout answers 403, and its session reports must_change_password: true. No body. Requires users:reset_password, and holding every role of the user or being an admin. Your own password is changed with PUT /api/me/password (409 here)."
    )

    tag("Users")
    produces("application/json")
    bearer_auth()
    id_param(:id, "User ID")
    response(200, "Password reset", Schema.ref(:PasswordResetResponse))

    error_response(
      403,
      "Forbidden - requires users:reset_password, or the user holds roles the caller does not"
    )

    error_response(404, "User not found")
    error_response(409, "The caller's own account")
  end

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

  # Swagger definitions
  def swagger_definitions do
    RephiWeb.Swagger.definitions(%{
      User: %{
        type: :object,
        title: "User",
        properties: %{
          id: %{type: :integer},
          email: %{type: :string},
          must_change_password: %{
            type: :boolean,
            description:
              "Its password was reset by an administrator and it has not set a new one yet"
          },
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
        required: [
          :id,
          :email,
          :must_change_password,
          :roles,
          :permissions,
          :inserted_at,
          :updated_at
        ]
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
              must_change_password: false,
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
      DirectUserPermission: %{
        type: :object,
        title: "Direct User Permission",
        description: "A permission granted to the user itself, with the grant",
        properties: %{
          id: %{type: :integer},
          name: %{type: :string},
          slug: %{type: :string},
          description: %{type: :string, "x-nullable": true},
          assigned_by: %{
            type: :integer,
            "x-nullable": true,
            description: "The user who granted it (null once that user is deleted)"
          },
          notes: %{type: :string, "x-nullable": true},
          granted_at: %{type: :string, format: :"date-time"}
        },
        required: [:id, :name, :slug, :description, :assigned_by, :notes, :granted_at]
      },
      EffectiveUserPermission: %{
        type: :object,
        title: "Effective User Permission",
        description: "A permission the user holds, and where it comes from",
        properties: %{
          id: %{type: :integer},
          name: %{type: :string},
          slug: %{type: :string},
          description: %{type: :string, "x-nullable": true},
          direct: %{type: :boolean, description: "Granted to the user itself"},
          roles: %{
            type: :array,
            description:
              "The roles that grant it, by slug: assigned to the user or inherited through the hierarchy (the role the permission is assigned to); [] when only direct",
            items: Schema.ref(:Grant)
          }
        },
        required: [:id, :name, :slug, :description, :direct, :roles]
      },
      UserPermissionsResponse: %{
        type: :object,
        title: "User Permissions Response",
        description:
          "The permissions granted to a user directly, and everything it may do with the source of each",
        properties: %{
          data: %{
            type: :object,
            properties: %{
              direct: %{type: :array, items: Schema.ref(:DirectUserPermission)},
              effective: %{type: :array, items: Schema.ref(:EffectiveUserPermission)}
            },
            required: [:direct, :effective]
          }
        },
        required: [:data],
        example: %{
          data: %{
            direct: [
              %{
                id: 12,
                name: "Export Reports",
                slug: "reports:export",
                description: nil,
                assigned_by: 1,
                notes: nil,
                granted_at: "2026-01-03T10:00:00Z"
              }
            ],
            effective: [
              %{
                id: 12,
                name: "Export Reports",
                slug: "reports:export",
                description: nil,
                direct: true,
                roles: []
              },
              %{
                id: 1,
                name: "View Users",
                slug: "users:view",
                description: "View user profiles and listings",
                direct: false,
                roles: [%{id: 2, name: "Manager", slug: "manager"}]
              }
            ]
          }
        }
      },
      PasswordResetResponse: %{
        type: :object,
        title: "Password Reset Response",
        description:
          "The user, now with must_change_password, and its temporary password (shown once)",
        properties: %{
          data: %{
            type: :object,
            properties: %{
              user: Schema.ref(:User),
              temporary_password: %{
                type: :string,
                description:
                  "Random, 24 characters; valid only to sign in and set a new password. It is not stored and cannot be retrieved again"
              }
            },
            required: [:user, :temporary_password]
          }
        },
        required: [:data],
        example: %{
          data: %{
            user: %{
              id: 5,
              email: "someone@example.com",
              must_change_password: true,
              roles: [%{id: 3, name: "User", slug: "user"}],
              permissions: [],
              inserted_at: "2026-01-03T10:00:00Z",
              updated_at: "2026-01-04T09:30:00Z"
            },
            temporary_password: "q3Vt0x9JmZr7KbN2LwYp4sHd"
          }
        }
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
