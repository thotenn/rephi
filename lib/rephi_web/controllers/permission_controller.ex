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
  a number, out of range) answers `404`. `GET /api/permissions` is paginated
  (`page`, `page_size`, see `Rephi.Pagination`).

  ## Rules

    * `parent_id` only groups permissions for display; holding a parent
      grants none of its children. Deleting a parent clears it on its
      children.
    * System permissions (`is_system`) cannot be deleted (`409`) and their
      slug cannot change (`422`).
    * Granting or revoking a permission requires holding it, or being an
      admin (`403` otherwise, `Rephi.Authorization.can_grant_permission?/2`).
    * Revoking from a role a permission it only inherits from a parent role
      answers `409`: revoke it from that role.
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
    description("One page of permissions, ordered by slug")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      page(:query, :integer, "Page, from 1 (default 1)", required: false)
      page_size(:query, :integer, "Entries per page (default 50, at most 100)", required: false)
    end

    response(200, "Success", Schema.ref(:PermissionsResponse))
    response(422, "Invalid page or page_size", Schema.ref(:ValidationErrors))
    response(401, "Unauthorized")
    response(403, "Forbidden - requires permissions:view permission")
  end

  def index(conn, params) do
    with {:ok, page} <- Authorization.paginate_permissions(params) do
      render(conn, :index, page: page)
    end
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
    response(409, "System permission")
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

    response(
      403,
      "Forbidden - requires permissions:assign, and holding the permission (or being an admin)"
    )

    response(404, "Role or permission not found")
    response(409, "Permission already assigned to role")
  end

  def assign_to_role(conn, %{"role_id" => role_id, "permission_id" => permission_id} = params) do
    opts = [actor: current_access(conn), notes: params["notes"]]

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

    response(
      403,
      "Forbidden - requires permissions:assign, and holding the permission (or being an admin)"
    )

    response(404, "Role or permission not found, or the role does not grant it")
    response(409, "The role only inherits the permission from a parent role")
  end

  def remove_from_role(conn, %{"role_id" => role_id, "permission_id" => permission_id}) do
    with {:ok, role} <- Authorization.fetch_role(role_id),
         {:ok, permission} <- Authorization.fetch_permission(permission_id),
         :ok <-
           Authorization.remove_permission_from_role(role, permission,
             actor: current_access(conn)
           ) do
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
          parent_id: %{
            type: :integer,
            description: "Parent permission ID, for grouping only (grants nothing)",
            nullable: true
          },
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
          name: "View Users",
          slug: "users:view",
          description: "Allows viewing user profiles and listings",
          parent_id: nil,
          is_system: true,
          inserted_at: "2025-01-03T10:00:00Z",
          updated_at: "2025-01-03T10:00:00Z"
        }
      },
      PermissionInput: %{
        type: :object,
        title: "Permission Input",
        description: "Permission creation/update data",
        properties: %{
          name: %{type: :string, maxLength: 255, description: "Permission display name"},
          slug: %{
            type: :string,
            maxLength: 100,
            pattern: "^[a-z0-9]+([_-][a-z0-9]+)*(:[a-z0-9]+([_-][a-z0-9]+)*)+$",
            description:
              "category:action (unique identifier); cannot change on a system permission"
          },
          description: %{type: :string, maxLength: 2000, description: "Permission description"},
          parent_id: %{
            type: :integer,
            description: "Parent permission ID, for grouping only",
            nullable: true
          }
        },
        required: [:name, :slug],
        example: %{
          name: "Create Reports",
          slug: "reports:create",
          description: "Allows creating new reports"
        }
      },
      PermissionsResponse: %{
        type: :object,
        title: "Permissions Response",
        description: "One page of permissions",
        properties: %{
          data: %{
            type: :array,
            items: Schema.ref(:Permission)
          },
          meta: Schema.ref(:PageMeta)
        },
        required: [:data, :meta]
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
