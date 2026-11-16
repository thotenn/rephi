defmodule RephiWeb.PermissionController do
  @moduledoc """
  Controller for managing permissions and their assignment to roles and
  users.

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
    * `POST/DELETE /api/users/:user_id/permissions/:permission_id` - Grant or revoke
      a permission of a user directly (requires "permissions:assign")

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
      answers `409`: revoke it from that role. Likewise for a user and a
      permission it only holds through a role.
  """
  use RephiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import RephiWeb.ApiSpec.Operations

  alias Rephi.Accounts
  alias Rephi.Authorization
  alias Rephi.Authorization.{Permission, UserPermission}
  alias RephiWeb.Schemas

  action_fallback RephiWeb.FallbackController

  tags ["Permissions"]
  security bearer_auth()

  plug AuthorizationPlug, {:permission, "permissions:view"} when action in [:index, :show]
  plug AuthorizationPlug, {:permission, "permissions:create"} when action in [:create]
  plug AuthorizationPlug, {:permission, "permissions:edit"} when action in [:update]
  plug AuthorizationPlug, {:permission, "permissions:delete"} when action in [:delete]

  plug AuthorizationPlug,
       {:permission, "permissions:assign"}
       when action in [:assign_to_role, :remove_from_role, :assign_to_user, :remove_from_user]

  operation :index,
    summary: "List permissions",
    description: "One page of permissions, ordered by slug. Requires permissions:view.",
    parameters: page_params(),
    responses:
      responses([
        :unauthorized,
        :password_settled,
        :invalid_page,
        ok: {"One page of permissions", Schemas.PermissionsResponse},
        forbidden: "Forbidden - requires permissions:view"
      ])

  def index(conn, params) do
    with {:ok, page} <- Authorization.paginate_permissions(params) do
      render(conn, :index, page: page)
    end
  end

  operation :show,
    summary: "Get a permission",
    description: "Requires permissions:view.",
    parameters: [id_param(:id, "Permission ID")],
    responses:
      responses([
        :unauthorized,
        :password_settled,
        ok: {"The permission", Schemas.PermissionResponse},
        forbidden: "Forbidden - requires permissions:view",
        not_found: "Permission not found"
      ])

  def show(conn, %{"id" => id}) do
    with {:ok, permission} <- Authorization.fetch_permission(id) do
      render(conn, :show, permission: permission)
    end
  end

  operation :create,
    summary: "Create a permission",
    description:
      "The attributes may also be wrapped under \"permission\". Requires permissions:create. The location header points to the new permission.",
    request_body: body("The permission", Schemas.PermissionInput),
    responses:
      responses([
        :unauthorized,
        :password_settled,
        :body_errors,
        created: {"Permission created", Schemas.PermissionResponse},
        forbidden: "Forbidden - requires permissions:create",
        unprocessable_entity: "Invalid or taken name or slug, or an unknown parent_id"
      ])

  def create(conn, _params) do
    attrs = resource_params(conn, "permission")

    with {:ok, %Permission{} = permission} <- Authorization.create_permission(attrs) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/permissions/#{permission}")
      |> render(:show, permission: permission)
    end
  end

  operation :update,
    summary: "Update a permission",
    description:
      "Changes the attributes sent; the others keep their value. The attributes may also be wrapped under \"permission\". The slug of a system permission cannot change (422). PUT and PATCH behave the same. Requires permissions:edit.",
    parameters: [id_param(:id, "Permission ID")],
    request_body: body("The attributes to change", Schemas.PermissionUpdate),
    responses:
      responses([
        :unauthorized,
        :password_settled,
        :body_errors,
        ok: {"Permission updated", Schemas.PermissionResponse},
        forbidden: "Forbidden - requires permissions:edit",
        not_found: "Permission not found",
        unprocessable_entity:
          "Invalid or taken name or slug, the slug of a system permission, or an invalid parent_id"
      ])

  def update(conn, %{"id" => id}) do
    attrs = resource_params(conn, "permission")

    with {:ok, permission} <- Authorization.fetch_permission(id),
         {:ok, %Permission{} = permission} <- Authorization.update_permission(permission, attrs) do
      render(conn, :show, permission: permission)
    end
  end

  operation :delete,
    summary: "Delete a permission",
    description: "Its children keep existing with parent_id null. Requires permissions:delete.",
    parameters: [id_param(:id, "Permission ID")],
    responses:
      responses([
        :unauthorized,
        :password_settled,
        no_content: "Permission deleted",
        forbidden: "Forbidden - requires permissions:delete",
        not_found: "Permission not found",
        conflict: "A system permission"
      ])

  def delete(conn, %{"id" => id}) do
    with {:ok, permission} <- Authorization.fetch_permission(id),
         {:ok, %Permission{}} <- Authorization.delete_permission(permission) do
      send_resp(conn, :no_content, "")
    end
  end

  operation :assign_to_role,
    summary: "Assign a permission to a role",
    description:
      "Requires permissions:assign, and holding the permission or being an admin. The body is optional. assigned_by is the caller.",
    parameters: [id_param(:role_id, "Role ID"), id_param(:permission_id, "Permission ID")],
    request_body: body("Optional notes", Schemas.AssignmentNotes, required: false),
    responses:
      responses([
        :unauthorized,
        :password_settled,
        :body_errors,
        created: {"Permission assigned", Schemas.RolePermissionAssignmentResponse},
        forbidden:
          "Forbidden - requires permissions:assign, and holding the permission or being an admin",
        not_found: "Role or permission not found",
        conflict: "Permission already assigned to role",
        unprocessable_entity: "notes is not a string or is too long"
      ])

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

  operation :remove_from_role,
    summary: "Remove a permission from a role",
    description:
      "Requires permissions:assign, and holding the permission or being an admin. A permission the role only inherits must be removed from the parent role that grants it (409).",
    parameters: [id_param(:role_id, "Role ID"), id_param(:permission_id, "Permission ID")],
    responses:
      responses([
        :unauthorized,
        :password_settled,
        no_content: "Permission removed",
        forbidden:
          "Forbidden - requires permissions:assign, and holding the permission or being an admin",
        not_found: "Role or permission not found, or the role does not grant it",
        conflict: "The role only inherits the permission from a parent role"
      ])

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

  operation :assign_to_user,
    summary: "Grant a permission to a user",
    description:
      "Grants the permission to the user directly, on top of what its roles grant. Requires permissions:assign, and holding the permission or being an admin. The body is optional. assigned_by is the caller.",
    parameters: [id_param(:user_id, "User ID"), id_param(:permission_id, "Permission ID")],
    request_body: body("Optional notes", Schemas.AssignmentNotes, required: false),
    responses:
      responses([
        :unauthorized,
        :password_settled,
        :body_errors,
        created: {"Permission granted", Schemas.UserPermissionAssignmentResponse},
        forbidden:
          "Forbidden - requires permissions:assign, and holding the permission or being an admin",
        not_found: "User or permission not found",
        conflict: "Permission already granted to the user directly",
        unprocessable_entity: "notes is not a string or is too long"
      ])

  def assign_to_user(conn, %{"user_id" => user_id, "permission_id" => permission_id} = params) do
    opts = [actor: current_access(conn), notes: params["notes"]]

    with {:ok, user} <- Accounts.fetch_user(user_id),
         {:ok, permission} <- Authorization.fetch_permission(permission_id),
         {:ok, %UserPermission{} = user_permission} <-
           user
           |> Authorization.assign_permission_to_user(permission, opts)
           |> conflict_if_taken("Permission already granted to the user") do
      conn
      |> put_status(:created)
      |> render(:user_assignment, user_permission: user_permission)
    end
  end

  operation :remove_from_user,
    summary: "Revoke a permission from a user",
    description:
      "Revokes a permission granted to the user directly. Requires permissions:assign, and holding the permission or being an admin. A permission the user only holds through a role must be removed from that role, or the role from the user (409).",
    parameters: [id_param(:user_id, "User ID"), id_param(:permission_id, "Permission ID")],
    responses:
      responses([
        :unauthorized,
        :password_settled,
        no_content: "Permission revoked",
        forbidden:
          "Forbidden - requires permissions:assign, and holding the permission or being an admin",
        not_found: "User or permission not found, or the user does not hold it",
        conflict: "The user only holds the permission through a role"
      ])

  def remove_from_user(conn, %{"user_id" => user_id, "permission_id" => permission_id}) do
    with {:ok, user} <- Accounts.fetch_user(user_id),
         {:ok, permission} <- Authorization.fetch_permission(permission_id),
         :ok <-
           Authorization.remove_permission_from_user(user, permission,
             actor: current_access(conn)
           ) do
      send_resp(conn, :no_content, "")
    end
  end
end
