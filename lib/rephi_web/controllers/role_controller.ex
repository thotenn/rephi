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
  use OpenApiSpex.ControllerSpecs

  import RephiWeb.ApiSpec.Operations

  alias Rephi.Accounts
  alias Rephi.Authorization
  alias Rephi.Authorization.Role
  alias RephiWeb.Schemas

  action_fallback RephiWeb.FallbackController

  tags ["Roles"]
  security bearer_auth()

  plug AuthorizationPlug,
       {:permission, "roles:view"} when action in [:index, :show, :get_role_permissions]

  plug AuthorizationPlug, {:permission, "roles:create"} when action in [:create]
  plug AuthorizationPlug, {:permission, "roles:edit"} when action in [:update]
  plug AuthorizationPlug, {:permission, "roles:delete"} when action in [:delete]

  plug AuthorizationPlug,
       {:permission, "roles:assign"} when action in [:assign_to_user, :remove_from_user]

  operation :index,
    summary: "List roles",
    description: "One page of roles, ordered by slug. Requires roles:view.",
    parameters: page_params(),
    responses:
      responses([
        :unauthorized,
        :invalid_page,
        ok: {"One page of roles", Schemas.RolesResponse},
        forbidden: "Forbidden - requires roles:view"
      ])

  def index(conn, params) do
    with {:ok, page} <- Authorization.paginate_roles(params) do
      render(conn, :index, page: page)
    end
  end

  operation :show,
    summary: "Get a role",
    description:
      "A role with the permissions assigned to it (permissions) and the ones it only inherits from its parent roles (inherited_permissions). Requires roles:view.",
    parameters: [id_param(:id, "Role ID")],
    responses:
      responses([
        :unauthorized,
        ok: {"The role", Schemas.RoleDetailResponse},
        forbidden: "Forbidden - requires roles:view",
        not_found: "Role not found"
      ])

  def show(conn, %{"id" => id}) do
    with {:ok, role} <- Authorization.fetch_role(id) do
      render(conn, :show, role: role, sources: Authorization.get_role_permission_sources(role))
    end
  end

  operation :create,
    summary: "Create a role",
    description:
      "The attributes may also be wrapped under \"role\". Requires roles:create. The location header points to the new role.",
    request_body: body("The role", Schemas.RoleInput),
    responses:
      responses([
        :unauthorized,
        :body_errors,
        created: {"Role created", Schemas.RoleDetailResponse},
        forbidden: "Forbidden - requires roles:create",
        unprocessable_entity: "Invalid or taken name or slug"
      ])

  def create(conn, _params) do
    with {:ok, %Role{} = role} <- Authorization.create_role(resource_params(conn, "role")) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/roles/#{role}")
      |> render(:show, role: role, sources: %{direct: [], inherited: []})
    end
  end

  operation :update,
    summary: "Update a role",
    description:
      "Changes the attributes sent; the others keep their value. The attributes may also be wrapped under \"role\". The slug of a system role cannot change (422). PUT and PATCH behave the same. Requires roles:edit.",
    parameters: [id_param(:id, "Role ID")],
    request_body: body("The attributes to change", Schemas.RoleUpdate),
    responses:
      responses([
        :unauthorized,
        :body_errors,
        ok: {"Role updated", Schemas.RoleDetailResponse},
        forbidden: "Forbidden - requires roles:edit",
        not_found: "Role not found",
        unprocessable_entity: "Invalid or taken name or slug, or the slug of a system role"
      ])

  def update(conn, %{"id" => id}) do
    with {:ok, role} <- Authorization.fetch_role(id),
         {:ok, %Role{} = role} <- Authorization.update_role(role, resource_params(conn, "role")) do
      render(conn, :show, role: role, sources: Authorization.get_role_permission_sources(role))
    end
  end

  operation :delete,
    summary: "Delete a role",
    description: "Requires roles:delete.",
    parameters: [id_param(:id, "Role ID")],
    responses:
      responses([
        :unauthorized,
        no_content: "Role deleted",
        forbidden: "Forbidden - requires roles:delete",
        not_found: "Role not found",
        conflict: "A system role, or deleting it would leave nobody with the admin role"
      ])

  def delete(conn, %{"id" => id}) do
    with {:ok, role} <- Authorization.fetch_role(id),
         {:ok, %Role{}} <- Authorization.delete_role(role) do
      send_resp(conn, :no_content, "")
    end
  end

  operation :assign_to_user,
    summary: "Assign a role to a user",
    description:
      "Requires roles:assign, and holding the role (assigned or inherited) or being an admin. The body is optional. assigned_by is the caller.",
    parameters: [id_param(:user_id, "User ID"), id_param(:role_id, "Role ID")],
    request_body: body("Optional notes", Schemas.AssignmentNotes, required: false),
    responses:
      responses([
        :unauthorized,
        :body_errors,
        created: {"Role assigned", Schemas.UserRoleAssignmentResponse},
        forbidden: "Forbidden - requires roles:assign, and holding the role or being an admin",
        not_found: "User or role not found",
        conflict: "Role already assigned to user",
        unprocessable_entity: "notes is not a string or is too long"
      ])

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

  operation :remove_from_user,
    summary: "Remove a role from a user",
    description:
      "Requires roles:assign, and holding the role (assigned or inherited) or being an admin.",
    parameters: [id_param(:user_id, "User ID"), id_param(:role_id, "Role ID")],
    responses:
      responses([
        :unauthorized,
        no_content: "Role removed",
        forbidden: "Forbidden - requires roles:assign, and holding the role or being an admin",
        not_found: "User or role not found, or the role is not assigned to the user",
        conflict: "It would leave nobody with the admin role"
      ])

  def remove_from_user(conn, %{"user_id" => user_id, "role_id" => role_id}) do
    with {:ok, user} <- Accounts.fetch_user(user_id),
         {:ok, role} <- Authorization.fetch_role(role_id),
         :ok <- Authorization.remove_role_from_user(user, role, actor: current_access(conn)) do
      send_resp(conn, :no_content, "")
    end
  end

  operation :get_role_permissions,
    summary: "List the permissions of a role",
    description:
      "Every permission the role grants, by slug: assigned to it (inherited: false) or inherited from its parent roles (inherited: true, inherited_from lists them). Not paginated. Requires roles:view.",
    parameters: [id_param(:id, "Role ID")],
    responses:
      responses([
        :unauthorized,
        ok: {"The permissions of the role", Schemas.RolePermissionsResponse},
        forbidden: "Forbidden - requires roles:view",
        not_found: "Role not found"
      ])

  def get_role_permissions(conn, %{"id" => id}) do
    with {:ok, role} <- Authorization.fetch_role(id) do
      render(conn, :permissions, sources: Authorization.get_role_permission_sources(role))
    end
  end
end
