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

  import RephiWeb.Swagger

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
    summary("List permissions")
    description("One page of permissions, ordered by slug. Requires permissions:view.")
    tag("Permissions")
    produces("application/json")
    bearer_auth()
    page_params()
    response(200, "One page of permissions", Schema.ref(:PermissionsResponse))
    error_response(403, "Forbidden - requires permissions:view")
  end

  def index(conn, params) do
    with {:ok, page} <- Authorization.paginate_permissions(params) do
      render(conn, :index, page: page)
    end
  end

  swagger_path :show do
    get("/api/permissions/{id}")
    summary("Get a permission")
    description("Requires permissions:view.")
    tag("Permissions")
    produces("application/json")
    bearer_auth()
    id_param(:id, "Permission ID")
    response(200, "The permission", Schema.ref(:PermissionResponse))
    error_response(403, "Forbidden - requires permissions:view")
    error_response(404, "Permission not found")
  end

  def show(conn, %{"id" => id}) do
    with {:ok, permission} <- Authorization.fetch_permission(id) do
      render(conn, :show, permission: permission)
    end
  end

  swagger_path :create do
    post("/api/permissions")
    summary("Create a permission")

    description(
      "The attributes may also be wrapped under \"permission\". Requires permissions:create. The location header points to the new permission."
    )

    tag("Permissions")
    consumes("application/json")
    produces("application/json")
    bearer_auth()

    parameters do
      body(:body, Schema.ref(:PermissionInput), "The permission", required: true)
    end

    response(201, "Permission created", Schema.ref(:PermissionResponse))
    body_errors()
    error_response(403, "Forbidden - requires permissions:create")
    validation_response("Invalid or taken name or slug, or an unknown parent_id")
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
    summary("Update a permission")

    description(
      "Changes the attributes sent; the others keep their value. The attributes may also be wrapped under \"permission\". The slug of a system permission cannot change (422). PUT and PATCH behave the same. Requires permissions:edit."
    )

    tag("Permissions")
    consumes("application/json")
    produces("application/json")
    bearer_auth()
    id_param(:id, "Permission ID")

    parameters do
      body(:body, Schema.ref(:PermissionUpdate), "The attributes to change", required: true)
    end

    response(200, "Permission updated", Schema.ref(:PermissionResponse))
    body_errors()
    error_response(403, "Forbidden - requires permissions:edit")
    error_response(404, "Permission not found")

    validation_response(
      "Invalid or taken name or slug, the slug of a system permission, or an invalid parent_id"
    )
  end

  defoverridable swagger_path_update: 1
  def swagger_path_update(route), do: route |> super() |> operation_per_verb()

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

    description("Its children keep existing with parent_id null. Requires permissions:delete.")

    tag("Permissions")
    produces("application/json")
    bearer_auth()
    id_param(:id, "Permission ID")
    response(204, "Permission deleted")
    error_response(403, "Forbidden - requires permissions:delete")
    error_response(404, "Permission not found")
    error_response(409, "A system permission")
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, permission} <- Authorization.fetch_permission(id),
         {:ok, %Permission{}} <- Authorization.delete_permission(permission) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :assign_to_role do
    post("/api/roles/{role_id}/permissions/{permission_id}")
    summary("Assign a permission to a role")

    description(
      "Requires permissions:assign, and holding the permission or being an admin. The body is optional. assigned_by is the caller."
    )

    tag("Permissions")
    consumes("application/json")
    produces("application/json")
    bearer_auth()
    id_param(:role_id, "Role ID")
    id_param(:permission_id, "Permission ID")

    parameters do
      body(:body, Schema.ref(:AssignmentNotes), "Optional notes", required: false)
    end

    response(201, "Permission assigned", Schema.ref(:RolePermissionAssignmentResponse))
    body_errors()

    error_response(
      403,
      "Forbidden - requires permissions:assign, and holding the permission or being an admin"
    )

    error_response(404, "Role or permission not found")
    error_response(409, "Permission already assigned to role")
    validation_response("notes is not a string or is too long")
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
    summary("Remove a permission from a role")

    description(
      "Requires permissions:assign, and holding the permission or being an admin. A permission the role only inherits must be removed from the parent role that grants it (409)."
    )

    tag("Permissions")
    produces("application/json")
    bearer_auth()
    id_param(:role_id, "Role ID")
    id_param(:permission_id, "Permission ID")
    response(204, "Permission removed")

    error_response(
      403,
      "Forbidden - requires permissions:assign, and holding the permission or being an admin"
    )

    error_response(404, "Role or permission not found, or the role does not grant it")
    error_response(409, "The role only inherits the permission from a parent role")
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
    RephiWeb.Swagger.definitions(%{
      Permission: %{
        type: :object,
        title: "Permission",
        properties: %{
          id: %{type: :integer},
          name: %{type: :string},
          slug: %{type: :string, description: "category:action, unique"},
          description: %{type: :string, "x-nullable": true},
          parent_id: %{
            type: :integer,
            "x-nullable": true,
            description: "Parent permission, for grouping only (holding it grants nothing)"
          },
          is_system: %{
            type: :boolean,
            description: "Part of the application (seeded): cannot be deleted, slug cannot change"
          },
          inserted_at: %{type: :string, format: :"date-time"},
          updated_at: %{type: :string, format: :"date-time"}
        },
        required: [
          :id,
          :name,
          :slug,
          :description,
          :parent_id,
          :is_system,
          :inserted_at,
          :updated_at
        ],
        example: %{
          id: 1,
          name: "View Users",
          slug: "users:view",
          description: "Can view user list and details",
          parent_id: nil,
          is_system: true,
          inserted_at: "2026-01-03T10:00:00Z",
          updated_at: "2026-01-03T10:00:00Z"
        }
      },
      PermissionInput: %{
        type: :object,
        title: "Permission Input",
        description: "A new permission",
        properties: %{
          name: %{type: :string, maxLength: 255},
          slug: %{
            type: :string,
            maxLength: 100,
            pattern: "^[a-z0-9]+([_-][a-z0-9]+)*(:[a-z0-9]+([_-][a-z0-9]+)*)+$",
            description: "category:action, unique"
          },
          description: %{type: :string, maxLength: 2000},
          parent_id: %{
            type: :integer,
            "x-nullable": true,
            description: "Parent permission, for grouping only"
          }
        },
        required: [:name, :slug],
        example: %{
          name: "Create Reports",
          slug: "reports:create",
          description: "Allows creating new reports"
        }
      },
      PermissionUpdate: %{
        type: :object,
        title: "Permission Update",
        description: "The attributes of a permission to change; all optional",
        properties: %{
          name: %{type: :string, maxLength: 255},
          slug: %{
            type: :string,
            maxLength: 100,
            pattern: "^[a-z0-9]+([_-][a-z0-9]+)*(:[a-z0-9]+([_-][a-z0-9]+)*)+$",
            description: "Cannot change on a system permission"
          },
          description: %{type: :string, maxLength: 2000},
          parent_id: %{
            type: :integer,
            "x-nullable": true,
            description: "Parent permission, for grouping only; not the permission itself"
          }
        },
        example: %{description: "Allows creating and scheduling reports"}
      },
      PermissionsResponse: %{
        type: :object,
        title: "Permissions Response",
        description: "One page of permissions",
        properties: %{
          data: %{type: :array, items: Schema.ref(:Permission)},
          meta: Schema.ref(:PageMeta)
        },
        required: [:data, :meta]
      },
      PermissionResponse: %{
        type: :object,
        title: "Permission Response",
        description: "A single permission",
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
              assigned_by: %{
                type: :integer,
                "x-nullable": true,
                description: "The user who assigned it (null once that user is deleted)"
              },
              notes: %{type: :string, "x-nullable": true},
              inserted_at: %{type: :string, format: :"date-time"}
            },
            required: [:role_id, :permission_id, :assigned_by, :notes, :inserted_at]
          }
        },
        required: [:data]
      }
    })
  end
end
