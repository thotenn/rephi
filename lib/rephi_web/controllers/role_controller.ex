defmodule RephiWeb.RoleController do
  @moduledoc """
  Controller for managing roles in the authorization system.

  This controller provides a full REST API for role management, including
  CRUD operations and role assignment to users. All actions are protected
  by appropriate permission checks.

  ## Endpoints

    * `GET /api/roles` - List all roles (requires "roles:view")
    * `POST /api/roles` - Create a new role (requires "roles:create")
    * `GET /api/roles/:id` - Get role details (requires "roles:view")
    * `PUT /api/roles/:id` - Update role (requires "roles:edit")
    * `DELETE /api/roles/:id` - Delete role (requires "roles:delete")
    * `POST /api/users/:user_id/roles/:role_id` - Assign role to user (requires "roles:assign")
    * `DELETE /api/users/:user_id/roles/:role_id` - Remove role from user (requires "roles:assign")

  `POST` and `PUT` accept the role attributes flat or wrapped under `"role"`.
  An id that is not the id of an existing record (unknown, not a number, out
  of range) answers `404`. `GET /api/roles` is paginated (`page`,
  `page_size`, see `Rephi.Pagination`).

  ## Rules

    * A role's detail separates the permissions assigned to it
      (`permissions`) from the ones it inherits from its parent roles
      (`inherited_permissions`, each with the roles it comes from).
    * System roles (`is_system`) cannot be deleted (`409`) and their slug
      cannot change (`422`).
    * Assigning or removing a role requires holding it, or being an admin
      (`403` otherwise, `Rephi.Authorization.can_grant_role?/2`).
    * Removing the admin role from its last holder, directly or by deleting
      a role that inherits from it, answers `409`.

  ## Permission Requirements

  All actions require authentication and specific permissions:
  - View actions: `roles:view`
  - Create actions: `roles:create`
  - Update actions: `roles:edit`
  - Delete actions: `roles:delete`
  - Assignment actions: `roles:assign`

  """
  use RephiWeb, :controller
  use PhoenixSwagger

  alias PhoenixSwagger.Schema
  alias Rephi.Accounts
  alias Rephi.Authorization
  alias Rephi.Authorization.Role

  action_fallback RephiWeb.FallbackController

  plug AuthorizationPlug,
       {:permission, "roles:view"} when action in [:index, :show, :get_role_permissions]

  plug AuthorizationPlug, {:permission, "roles:create"} when action in [:create]
  plug AuthorizationPlug, {:permission, "roles:edit"} when action in [:update]
  plug AuthorizationPlug, {:permission, "roles:delete"} when action in [:delete]

  plug AuthorizationPlug,
       {:permission, "roles:assign"} when action in [:assign_to_user, :remove_from_user]

  swagger_path :index do
    get("/api/roles")
    summary("List all roles")
    description("One page of roles, ordered by slug")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      page(:query, :integer, "Page, from 1 (default 1)", required: false)
      page_size(:query, :integer, "Entries per page (default 50, at most 100)", required: false)
    end

    response(200, "Success", Schema.ref(:RolesResponse))
    response(422, "Invalid page or page_size", Schema.ref(:ValidationErrors))
    response(401, "Unauthorized")
    response(403, "Forbidden - requires roles:view permission")
  end

  def index(conn, params) do
    with {:ok, page} <- Authorization.paginate_roles(params) do
      render(conn, :index, page: page)
    end
  end

  swagger_path :show do
    get("/api/roles/{id}")
    summary("Get role details")

    description(
      "A role with the permissions assigned to it (permissions) and the ones it inherits from its parent roles (inherited_permissions)"
    )

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Role ID", required: true)
    end

    response(200, "Success", Schema.ref(:RoleDetailResponse))
    response(401, "Unauthorized")
    response(403, "Forbidden - requires roles:view permission")
    response(404, "Role not found")
  end

  def show(conn, %{"id" => id}) do
    with {:ok, role} <- Authorization.fetch_role(id) do
      render(conn, :show, role: role, sources: Authorization.get_role_permission_sources(role))
    end
  end

  swagger_path :create do
    post("/api/roles")
    summary("Create a new role")
    description("Creates a new role in the system")
    consumes("application/json")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      role(:body, Schema.ref(:RoleInput), "Role details", required: true)
    end

    response(201, "Role created successfully", Schema.ref(:RoleDetailResponse))
    response(400, "Bad request")
    response(401, "Unauthorized")
    response(403, "Forbidden - requires roles:create permission")
    response(422, "Validation errors")
  end

  def create(conn, _params) do
    with {:ok, %Role{} = role} <- Authorization.create_role(resource_params(conn, "role")) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/roles/#{role}")
      |> render(:show, role: role, sources: %{direct: [], inherited: []})
    end
  end

  swagger_path :update do
    put("/api/roles/{id}")
    summary("Update a role")
    description("Updates an existing role")
    consumes("application/json")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Role ID", required: true)
      role(:body, Schema.ref(:RoleInput), "Updated role details", required: true)
    end

    response(200, "Role updated successfully", Schema.ref(:RoleDetailResponse))
    response(400, "Bad request")
    response(401, "Unauthorized")
    response(403, "Forbidden - requires roles:edit permission")
    response(404, "Role not found")
    response(422, "Validation errors")
  end

  def update(conn, %{"id" => id}) do
    with {:ok, role} <- Authorization.fetch_role(id),
         {:ok, %Role{} = role} <- Authorization.update_role(role, resource_params(conn, "role")) do
      render(conn, :show, role: role, sources: Authorization.get_role_permission_sources(role))
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/roles/{id}")
    summary("Delete a role")
    description("Deletes a role from the system")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Role ID", required: true)
    end

    response(204, "Role deleted successfully")
    response(401, "Unauthorized")
    response(403, "Forbidden - requires roles:delete permission")
    response(404, "Role not found")
    response(409, "System role, or it would leave nobody with the admin role")
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, role} <- Authorization.fetch_role(id),
         {:ok, %Role{}} <- Authorization.delete_role(role) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :assign_to_user do
    post("/api/users/{user_id}/roles/{role_id}")
    summary("Assign role to user")
    description("Assigns a role to a specific user")
    consumes("application/json")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      user_id(:path, :string, "User ID", required: true)
      role_id(:path, :string, "Role ID", required: true)
      body(:body, Schema.ref(:AssignmentNotes), "Assignment notes", required: false)
    end

    response(201, "Role assigned successfully", Schema.ref(:UserRoleAssignmentResponse))
    response(401, "Unauthorized")

    response(
      403,
      "Forbidden - requires roles:assign, and holding the role (or being an admin)"
    )

    response(404, "User or role not found")
    response(409, "Role already assigned to user")
  end

  def assign_to_user(conn, %{"user_id" => user_id, "role_id" => role_id} = params) do
    opts = [actor: current_access(conn), notes: params["notes"]]

    with {:ok, user} <- Accounts.fetch_user(user_id),
         {:ok, role} <- Authorization.fetch_role(role_id),
         {:ok, user_role} <-
           user
           |> Authorization.assign_role_to_user(role, opts)
           |> conflict_if_taken("Role already assigned to user") do
      conn
      |> put_status(:created)
      |> render(:assignment, user_role: user_role)
    end
  end

  swagger_path :remove_from_user do
    PhoenixSwagger.Path.delete("/api/users/{user_id}/roles/{role_id}")
    summary("Remove role from user")
    description("Removes a role from a specific user")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      user_id(:path, :string, "User ID", required: true)
      role_id(:path, :string, "Role ID", required: true)
    end

    response(204, "Role removed successfully")
    response(401, "Unauthorized")

    response(
      403,
      "Forbidden - requires roles:assign, and holding the role (or being an admin)"
    )

    response(404, "User or role not found, or the user does not have the role")
    response(409, "It would leave nobody with the admin role")
  end

  def remove_from_user(conn, %{"user_id" => user_id, "role_id" => role_id}) do
    with {:ok, user} <- Accounts.fetch_user(user_id),
         {:ok, role} <- Authorization.fetch_role(role_id),
         :ok <- Authorization.remove_role_from_user(user, role, actor: current_access(conn)) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :get_role_permissions do
    get("/api/roles/{id}/permissions")
    summary("Get role permissions")

    description(
      "Every permission the role grants: assigned to it (inherited: false) or inherited from its parent roles (inherited: true, inherited_from lists them)"
    )

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Role ID", required: true)
    end

    response(200, "Success", Schema.ref(:RolePermissionsResponse))
    response(401, "Unauthorized")
    response(403, "Forbidden - requires roles:view permission")
    response(404, "Role not found")
  end

  def get_role_permissions(conn, %{"id" => id}) do
    with {:ok, role} <- Authorization.fetch_role(id) do
      render(conn, :permissions, sources: Authorization.get_role_permission_sources(role))
    end
  end

  # Swagger schema definitions
  def swagger_definitions do
    %{
      Role: %{
        type: :object,
        title: "Role",
        description: "Role details",
        properties: %{
          id: %{type: :integer, description: "Role ID"},
          name: %{type: :string, description: "Role display name"},
          slug: %{type: :string, description: "Role slug (unique identifier)"},
          description: %{type: :string, description: "Role description"},
          is_system: %{
            type: :boolean,
            description: "Part of the application: cannot be deleted, slug cannot change"
          },
          inserted_at: %{type: :string, format: :"date-time", description: "Creation timestamp"},
          updated_at: %{type: :string, format: :"date-time", description: "Last update timestamp"}
        },
        required: [:id, :name, :slug, :is_system],
        example: %{
          id: 1,
          name: "Manager",
          slug: "manager",
          description: "Manages teams and resources",
          is_system: true,
          inserted_at: "2025-01-03T10:00:00Z",
          updated_at: "2025-01-03T10:00:00Z"
        }
      },
      RoleInput: %{
        type: :object,
        title: "Role Input",
        description: "Role creation/update data",
        properties: %{
          name: %{type: :string, maxLength: 255, description: "Role display name"},
          slug: %{
            type: :string,
            maxLength: 100,
            pattern: "^[a-z0-9]+([_-][a-z0-9]+)*$",
            description: "Role slug (unique identifier); cannot change on a system role"
          },
          description: %{type: :string, maxLength: 2000, description: "Role description"}
        },
        required: [:name, :slug],
        example: %{
          name: "Content Editor",
          slug: "content_editor",
          description: "Can create and edit content"
        }
      },
      RolesResponse: %{
        type: :object,
        title: "Roles Response",
        description: "One page of roles",
        properties: %{
          data: %{
            type: :array,
            items: Schema.ref(:Role)
          },
          meta: Schema.ref(:PageMeta)
        },
        required: [:data, :meta]
      },
      RoleGrantSource: %{
        type: :object,
        title: "Role Grant Source",
        description: "A parent role a permission is inherited from",
        properties: %{id: %{type: :integer}, name: %{type: :string}, slug: %{type: :string}},
        required: [:id, :name, :slug]
      },
      InheritedPermission: %{
        type: :object,
        title: "Inherited Permission",
        description: "A permission a role inherits from its parent roles",
        properties: %{
          id: %{type: :integer},
          name: %{type: :string},
          slug: %{type: :string},
          description: %{type: :string},
          inherited_from: %{type: :array, items: Schema.ref(:RoleGrantSource)}
        },
        required: [:id, :name, :slug, :inherited_from]
      },
      RoleDetailResponse: %{
        type: :object,
        title: "Role Detail Response",
        description:
          "A role with the permissions assigned to it and the ones it inherits (not assigned to it)",
        properties: %{
          data: %{
            type: :object,
            properties: %{
              id: %{type: :integer},
              name: %{type: :string},
              slug: %{type: :string},
              description: %{type: :string},
              is_system: %{type: :boolean},
              inserted_at: %{type: :string, format: :"date-time"},
              updated_at: %{type: :string, format: :"date-time"},
              permissions: %{
                type: :array,
                description: "Assigned to the role itself",
                items: Schema.ref(:RolePermissionSummary)
              },
              inherited_permissions: %{
                type: :array,
                description: "Inherited from parent roles only",
                items: Schema.ref(:InheritedPermission)
              }
            },
            required: [:id, :name, :slug, :is_system, :permissions, :inherited_permissions]
          }
        },
        required: [:data],
        example: %{
          data: %{
            id: 2,
            name: "Manager",
            slug: "manager",
            description: "Manages teams and resources",
            is_system: true,
            inserted_at: "2025-01-03T10:00:00Z",
            updated_at: "2025-01-03T10:00:00Z",
            permissions: [
              %{id: 5, name: "View Roles", slug: "roles:view", description: "View roles"}
            ],
            inherited_permissions: [
              %{
                id: 9,
                name: "Some Permission",
                slug: "things:view",
                description: nil,
                inherited_from: [%{id: 3, name: "User", slug: "user"}]
              }
            ]
          }
        }
      },
      RolePermissionSummary: %{
        type: :object,
        title: "Role Permission",
        properties: %{
          id: %{type: :integer},
          name: %{type: :string},
          slug: %{type: :string},
          description: %{type: :string}
        },
        required: [:id, :name, :slug]
      },
      AssignmentNotes: %{
        type: :object,
        title: "Assignment Notes",
        description: "Optional notes for role/permission assignment",
        properties: %{
          notes: %{type: :string, maxLength: 2000, description: "Assignment notes"}
        },
        example: %{
          notes: "Assigned for project X management"
        }
      },
      UserRoleAssignmentResponse: %{
        type: :object,
        title: "User Role Assignment Response",
        description: "The assignment created by giving a role to a user",
        properties: %{
          data: %{
            type: :object,
            properties: %{
              user_id: %{type: :integer},
              role_id: %{type: :integer},
              assigned_by: %{type: :integer, description: "ID of the user who assigned it"},
              notes: %{type: :string},
              inserted_at: %{type: :string, format: :"date-time"}
            },
            required: [:user_id, :role_id]
          }
        },
        required: [:data]
      },
      RolePermissionsResponse: %{
        type: :object,
        title: "Role Permissions Response",
        description: "Every permission the role grants, assigned or inherited",
        properties: %{
          data: %{
            type: :array,
            items: %{
              type: :object,
              properties: %{
                id: %{type: :integer},
                name: %{type: :string},
                slug: %{type: :string},
                description: %{type: :string},
                inherited: %{
                  type: :boolean,
                  description: "Not assigned to the role, only inherited"
                },
                inherited_from: %{type: :array, items: Schema.ref(:RoleGrantSource)}
              },
              required: [:id, :name, :slug, :inherited, :inherited_from]
            }
          }
        }
      }
    }
  end
end
