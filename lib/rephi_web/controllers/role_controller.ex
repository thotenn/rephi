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

  alias Rephi.Authorization
  alias Rephi.Authorization.Role
  alias PhoenixSwagger.Schema

  action_fallback RephiWeb.FallbackController

  plug AuthorizationPlug, {:permission, "roles:view"} when action in [:index, :show]
  plug AuthorizationPlug, {:permission, "roles:create"} when action in [:create]
  plug AuthorizationPlug, {:permission, "roles:edit"} when action in [:update]
  plug AuthorizationPlug, {:permission, "roles:delete"} when action in [:delete]
  plug AuthorizationPlug, {:permission, "roles:assign"} when action in [:assign_to_user, :remove_from_user]

  swagger_path :index do
    get("/api/roles")
    summary("List all roles")
    description("Returns a list of all available roles in the system")
    produces("application/json")
    security([%{Bearer: []}])
    
    response(200, "Success", Schema.ref(:RolesResponse))
    response(401, "Unauthorized")
    response(403, "Forbidden - requires roles:view permission")
  end

  def index(conn, _params) do
    roles = Authorization.list_roles()
    render(conn, :index, roles: roles)
  end

  swagger_path :show do
    get("/api/roles/{id}")
    summary("Get role details")
    description("Returns detailed information about a specific role including its permissions")
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
    role = Authorization.get_role!(id)
    permissions = Authorization.get_role_permissions(role)
    
    render(conn, :show, role: role, permissions: permissions)
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

  def create(conn, %{"role" => role_params}) do
    with {:ok, %Role{} = role} <- Authorization.create_role(role_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/roles/#{role}")
      |> render(:show, role: role, permissions: [])
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

  def update(conn, %{"id" => id, "role" => role_params}) do
    role = Authorization.get_role!(id)

    with {:ok, %Role{} = role} <- Authorization.update_role(role, role_params) do
      permissions = Authorization.get_role_permissions(role)
      render(conn, :show, role: role, permissions: permissions)
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
  end

  def delete(conn, %{"id" => id}) do
    role = Authorization.get_role!(id)

    with {:ok, %Role{}} <- Authorization.delete_role(role) do
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
    
    response(201, "Role assigned successfully")
    response(401, "Unauthorized")
    response(403, "Forbidden - requires roles:assign permission")
    response(404, "User or role not found")
    response(409, "Role already assigned to user")
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
    response(403, "Forbidden - requires roles:assign permission")
    response(404, "User or role not found")
  end

  def remove_from_user(conn, %{"user_id" => user_id, "role_id" => role_id}) do
    user = Rephi.Accounts.get_user!(user_id)
    role = Authorization.get_role!(role_id)

    with {:ok, _} <- Authorization.remove_role_from_user(user, role) do
      send_resp(conn, :no_content, "")
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
          parent_id: %{type: :integer, description: "Parent role ID for hierarchy", nullable: true},
          inserted_at: %{type: :string, format: :datetime, description: "Creation timestamp"},
          updated_at: %{type: :string, format: :datetime, description: "Last update timestamp"}
        },
        required: [:id, :name, :slug],
        example: %{
          id: 1,
          name: "Manager",
          slug: "manager",
          description: "Manages teams and resources",
          parent_id: nil,
          inserted_at: "2025-01-03T10:00:00Z",
          updated_at: "2025-01-03T10:00:00Z"
        }
      },
      RoleInput: %{
        type: :object,
        title: "Role Input",
        description: "Role creation/update data",
        properties: %{
          name: %{type: :string, description: "Role display name"},
          slug: %{type: :string, description: "Role slug (unique identifier)"},
          description: %{type: :string, description: "Role description"},
          parent_id: %{type: :integer, description: "Parent role ID for hierarchy", nullable: true}
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
        description: "List of roles",
        properties: %{
          data: %{
            type: :array,
            items: Schema.ref(:Role)
          }
        },
        required: [:data]
      },
      RoleDetailResponse: %{
        type: :object,
        title: "Role Detail Response",
        description: "Role with permissions",
        properties: %{
          data: %{
            type: :object,
            properties: %{
              role: Schema.ref(:Role),
              permissions: %{
                type: :array,
                items: Schema.ref(:Permission)
              }
            }
          }
        },
        required: [:data],
        example: %{
          data: %{
            role: %{
              id: 1,
              name: "Manager",
              slug: "manager",
              description: "Manages teams and resources"
            },
            permissions: [
              %{
                id: 1,
                name: "View Users",
                slug: "users:view",
                category: "users"
              },
              %{
                id: 2,
                name: "Create Users",
                slug: "users:create",
                category: "users"
              }
            ]
          }
        }
      },
      AssignmentNotes: %{
        type: :object,
        title: "Assignment Notes",
        description: "Optional notes for role/permission assignment",
        properties: %{
          notes: %{type: :string, description: "Assignment notes"}
        },
        example: %{
          notes: "Assigned for project X management"
        }
      }
    }
  end

end