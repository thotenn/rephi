defmodule RephiWeb.PermissionController do
  @moduledoc """
  Controller for managing permissions and their assignment to roles.

  ## Endpoints

    * `GET /api/permissions` - List all permissions (requires "permissions:view")
    * `POST /api/permissions` - Create a permission (requires "permissions:create")
    * `GET /api/permissions/:id` - Get a permission (requires "permissions:view")
    * `PUT /api/permissions/:id` - Update a permission (requires "permissions:edit")
    * `DELETE /api/permissions/:id` - Delete a permission (requires "permissions:delete")
    * `POST /api/roles/:role_id/permissions/:permission_id` - Assign a permission
      to a role (requires "permissions:assign")
    * `DELETE /api/roles/:role_id/permissions/:permission_id` - Remove a permission
      from a role (requires "permissions:assign")

  `POST` and `PUT` accept the permission attributes flat or wrapped under
  `"permission"`. An id that is not the id of an existing record (unknown, not
  a number, out of range) answers `404`.
  """
  use RephiWeb, :controller
  use PhoenixSwagger

  alias PhoenixSwagger.Schema
  alias Rephi.Authorization
  alias Rephi.Authorization.Permission

  action_fallback RephiWeb.FallbackController

  plug AuthorizationPlug, {:permission, "permissions:view"} when action in [:index, :show]
  plug AuthorizationPlug, {:permission, "permissions:create"} when action in [:create]
  plug AuthorizationPlug, {:permission, "permissions:edit"} when action in [:update]
  plug AuthorizationPlug, {:permission, "permissions:delete"} when action in [:delete]

  plug AuthorizationPlug,
       {:permission, "permissions:assign"} when action in [:assign_to_role, :remove_from_role]

  swagger_path :index do
    get("/api/permissions")
    summary("List all permissions")
    description("Returns a list of all available permissions in the system")
    produces("application/json")
    security([%{Bearer: []}])

    response(200, "Success", Schema.ref(:PermissionsResponse))
    response(401, "Unauthorized")
    response(403, "Forbidden - requires permissions:view permission")
  end

  def index(conn, _params) do
    permissions = Authorization.list_permissions()
    render(conn, :index, permissions: permissions)
  end

  swagger_path :show do
    get("/api/permissions/{id}")
    summary("Get permission details")
    description("Returns detailed information about a specific permission")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Permission ID", required: true)
    end

    response(200, "Success", Schema.ref(:PermissionResponse))
    response(401, "Unauthorized")
    response(403, "Forbidden - requires permissions:view permission")
    response(404, "Permission not found")
  end

  def show(conn, %{"id" => id}) do
    with {:ok, permission} <- Authorization.fetch_permission(id) do
      render(conn, :show, permission: permission)
    end
  end

  swagger_path :create do
    post("/api/permissions")
    summary("Create a new permission")
    description("Creates a new permission in the system")
    consumes("application/json")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      permission(:body, Schema.ref(:PermissionInput), "Permission details", required: true)
    end

    response(201, "Permission created successfully", Schema.ref(:PermissionResponse))
    response(400, "Bad request")
    response(401, "Unauthorized")
    response(403, "Forbidden - requires permissions:create permission")
    response(422, "Validation errors")
  end

  def create(conn, _params) do
    attrs = resource_params(conn, "permission")

    with {:ok, %Permission{} = permission} <- Authorization.create_permission(attrs) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/permissions/#{permission}")
      |> render(:show, permission: permission)
    end
  end

  swagger_path :update do
    put("/api/permissions/{id}")
    summary("Update a permission")
    description("Updates an existing permission")
    consumes("application/json")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Permission ID", required: true)

      permission(:body, Schema.ref(:PermissionInput), "Updated permission details",
        required: true
      )
    end

    response(200, "Permission updated successfully", Schema.ref(:PermissionResponse))
    response(400, "Bad request")
    response(401, "Unauthorized")
    response(403, "Forbidden - requires permissions:edit permission")
    response(404, "Permission not found")
    response(422, "Validation errors")
  end

  def update(conn, %{"id" => id}) do
    attrs = resource_params(conn, "permission")

    with {:ok, permission} <- Authorization.fetch_permission(id),
         {:ok, %Permission{} = permission} <- Authorization.update_permission(permission, attrs) do
      render(conn, :show, permission: permission)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/permissions/{id}")
    summary("Delete a permission")
    description("Deletes a permission from the system")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Permission ID", required: true)
    end

    response(204, "Permission deleted successfully")
    response(401, "Unauthorized")
    response(403, "Forbidden - requires permissions:delete permission")
    response(404, "Permission not found")
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, permission} <- Authorization.fetch_permission(id),
         {:ok, %Permission{}} <- Authorization.delete_permission(permission) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :assign_to_role do
    post("/api/roles/{role_id}/permissions/{permission_id}")
    summary("Assign permission to role")
    description("Assigns a permission to a specific role")
    consumes("application/json")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      role_id(:path, :string, "Role ID", required: true)
      permission_id(:path, :string, "Permission ID", required: true)
      body(:body, Schema.ref(:AssignmentNotes), "Assignment notes", required: false)
    end

    response(
      201,
      "Permission assigned successfully",
      Schema.ref(:RolePermissionAssignmentResponse)
    )

    response(401, "Unauthorized")
    response(403, "Forbidden - requires permissions:assign permission")
    response(404, "Role or permission not found")
    response(409, "Permission already assigned to role")
  end

  def assign_to_role(conn, %{"role_id" => role_id, "permission_id" => permission_id} = params) do
    opts = %{assigned_by: conn.assigns.current_user.id, notes: params["notes"]}

    with {:ok, role} <- Authorization.fetch_role(role_id),
         {:ok, permission} <- Authorization.fetch_permission(permission_id),
         {:ok, role_permission} <-
           role
           |> Authorization.assign_permission_to_role(permission, opts)
           |> conflict_if_taken("Permission already assigned to role") do
      conn
      |> put_status(:created)
      |> render(:assignment, role_permission: role_permission)
    end
  end

  swagger_path :remove_from_role do
    PhoenixSwagger.Path.delete("/api/roles/{role_id}/permissions/{permission_id}")
    summary("Remove permission from role")
    description("Removes a permission from a specific role")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      role_id(:path, :string, "Role ID", required: true)
      permission_id(:path, :string, "Permission ID", required: true)
    end

    response(204, "Permission removed successfully")
    response(401, "Unauthorized")
    response(403, "Forbidden - requires permissions:assign permission")
    response(404, "Role or permission not found")
  end

  def remove_from_role(conn, %{"role_id" => role_id, "permission_id" => permission_id}) do
    with {:ok, role} <- Authorization.fetch_role(role_id),
         {:ok, permission} <- Authorization.fetch_permission(permission_id),
         {:ok, _role_permission} <- Authorization.remove_permission_from_role(role, permission) do
      send_resp(conn, :no_content, "")
    end
  end

  # Swagger schema definitions
  def swagger_definitions do
    %{
      Permission: %{
        type: :object,
        title: "Permission",
        description: "Permission details",
        properties: %{
          id: %{type: :integer, description: "Permission ID"},
          name: %{type: :string, description: "Permission display name"},
          slug: %{type: :string, description: "Permission slug (unique identifier)"},
          description: %{type: :string, description: "Permission description"},
          category: %{type: :string, description: "Permission category"},
          parent_id: %{type: :integer, description: "Parent permission ID", nullable: true},
          inserted_at: %{type: :string, format: :datetime, description: "Creation timestamp"},
          updated_at: %{type: :string, format: :datetime, description: "Last update timestamp"}
        },
        required: [:id, :name, :slug],
        example: %{
          id: 1,
          name: "View Users",
          slug: "users:view",
          description: "Allows viewing user profiles and listings",
          category: "users",
          parent_id: nil,
          inserted_at: "2025-01-03T10:00:00Z",
          updated_at: "2025-01-03T10:00:00Z"
        }
      },
      PermissionInput: %{
        type: :object,
        title: "Permission Input",
        description: "Permission creation/update data",
        properties: %{
          name: %{type: :string, description: "Permission display name"},
          slug: %{type: :string, description: "Permission slug (unique identifier)"},
          description: %{type: :string, description: "Permission description"},
          category: %{type: :string, description: "Permission category"},
          parent_id: %{type: :integer, description: "Parent permission ID", nullable: true}
        },
        required: [:name, :slug],
        example: %{
          name: "Create Reports",
          slug: "reports:create",
          description: "Allows creating new reports",
          category: "reports"
        }
      },
      PermissionsResponse: %{
        type: :object,
        title: "Permissions Response",
        description: "List of permissions",
        properties: %{
          data: %{
            type: :array,
            items: Schema.ref(:Permission)
          }
        },
        required: [:data]
      },
      PermissionResponse: %{
        type: :object,
        title: "Permission Response",
        description: "Single permission response",
        properties: %{
          data: Schema.ref(:Permission)
        },
        required: [:data]
      },
      RolePermissionAssignmentResponse: %{
        type: :object,
        title: "Role Permission Assignment Response",
        description: "The assignment created by giving a permission to a role",
        properties: %{
          data: %{
            type: :object,
            properties: %{
              role_id: %{type: :integer},
              permission_id: %{type: :integer},
              assigned_by: %{type: :integer, description: "ID of the user who assigned it"},
              notes: %{type: :string},
              inserted_at: %{type: :string, format: :"date-time"}
            },
            required: [:role_id, :permission_id]
          }
        },
        required: [:data]
      }
    }
  end
end
