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
    * `GET /api/roles/:id/parents`, `GET /api/roles/:id/children` (requires "roles:view")
    * `POST/DELETE /api/roles/:role_id/parents/:parent_id` (requires "roles:edit")

  Assigning, removing or linking a role requires holding it, or being an admin.

  ## Permission Requirements

  All actions require authentication and specific permissions:
  - View actions: `roles:view`
  - Create actions: `roles:create`
  - Update actions: `roles:edit`
  - Delete actions: `roles:delete`
  - Assignment actions: `roles:assign`
  - Hierarchy changes: `roles:edit`

  """
  use RephiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import RephiWeb.ApiSpec.Operations

  alias Rephi.Accounts
  alias Rephi.Authorization
  alias Rephi.Authorization.{Role, RoleRole}
  alias RephiWeb.Schemas

  action_fallback RephiWeb.FallbackController

  tags ["Roles"]
  security bearer_auth()

  plug AuthorizationPlug,
       {:permission, "roles:view"}
       when action in [
              :index,
              :show,
              :get_role_permissions,
              :get_role_parents,
              :get_role_children
            ]

  plug AuthorizationPlug, {:permission, "roles:create"} when action in [:create]

  plug AuthorizationPlug,
       {:permission, "roles:edit"} when action in [:update, :add_parent, :remove_parent]

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
        :password_settled,
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
        :password_settled,
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
        :password_settled,
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
        :password_settled,
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
        :password_settled,
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
        :password_settled,
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
        :password_settled,
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
        :password_settled,
        ok: {"The permissions of the role", Schemas.RolePermissionsResponse},
        forbidden: "Forbidden - requires roles:view",
        not_found: "Role not found"
      ])

  def get_role_permissions(conn, %{"id" => id}) do
    with {:ok, role} <- Authorization.fetch_role(id) do
      render(conn, :permissions, sources: Authorization.get_role_permission_sources(role))
    end
  end

  operation :get_role_parents,
    summary: "List the parent roles of a role",
    description:
      "The roles this role inherits from directly (not their own ancestors; the permissions inherited through the whole chain are in inherited_permissions of GET /api/roles/{id}), by slug, each with its link. Not paginated. Requires roles:view.",
    parameters: [id_param(:id, "Role ID")],
    responses:
      responses([
        :unauthorized,
        :password_settled,
        ok: {"The parent roles", Schemas.RoleLinksResponse},
        forbidden: "Forbidden - requires roles:view",
        not_found: "Role not found"
      ])

  def get_role_parents(conn, %{"id" => id}) do
    with {:ok, role} <- Authorization.fetch_role(id) do
      render(conn, :links, links: Authorization.list_parent_roles(role))
    end
  end

  operation :get_role_children,
    summary: "List the child roles of a role",
    description:
      "The roles that inherit from this role directly, by slug, each with its link. Not paginated. Requires roles:view.",
    parameters: [id_param(:id, "Role ID")],
    responses:
      responses([
        :unauthorized,
        :password_settled,
        ok: {"The child roles", Schemas.RoleLinksResponse},
        forbidden: "Forbidden - requires roles:view",
        not_found: "Role not found"
      ])

  def get_role_children(conn, %{"id" => id}) do
    with {:ok, role} <- Authorization.fetch_role(id) do
      render(conn, :links, links: Authorization.list_child_roles(role))
    end
  end

  operation :add_parent,
    summary: "Make a role inherit from another",
    description:
      "Links parent_id as a parent of role_id: every holder of role_id gets the permissions of parent_id and of its ancestors. Requires roles:edit, and holding both roles (assigned or inherited) or being an admin. The body is optional. assigned_by is the caller. Refused (409) when it would make a role inherit from itself (parent_id is role_id or one of its descendants) or the parent is already linked.",
    parameters: [
      id_param(:role_id, "Role ID (the child)"),
      id_param(:parent_id, "Parent role ID")
    ],
    request_body: body("Optional notes", Schemas.AssignmentNotes, required: false),
    responses:
      responses([
        :unauthorized,
        :password_settled,
        :body_errors,
        created: {"Parent linked", Schemas.RoleParentAssignmentResponse},
        forbidden: "Forbidden - requires roles:edit, and holding both roles or being an admin",
        not_found: "Role or parent role not found",
        conflict: "The role would inherit from itself, or the parent is already linked",
        unprocessable_entity: "notes is not a string or is too long"
      ])

  def add_parent(conn, %{"role_id" => role_id, "parent_id" => parent_id} = params) do
    opts = [actor: current_access(conn), notes: params["notes"]]

    with {:ok, role} <- Authorization.fetch_role(role_id),
         {:ok, parent} <- Authorization.fetch_role(parent_id),
         {:ok, %RoleRole{} = link} <-
           role
           |> Authorization.assign_parent_role(parent, opts)
           |> conflict_if_taken("The role already inherits from this parent")
           |> conflict_if_cycle() do
      conn
      |> put_status(:created)
      |> render(:parent_assignment, link: link)
    end
  end

  operation :remove_parent,
    summary: "Remove a parent from a role",
    description:
      "role_id stops inheriting from parent_id. Requires roles:edit, and holding both roles (assigned or inherited) or being an admin. The links of the default hierarchy (is_system) cannot be removed, nor a link through which the last admins hold the admin role (409).",
    parameters: [
      id_param(:role_id, "Role ID (the child)"),
      id_param(:parent_id, "Parent role ID")
    ],
    responses:
      responses([
        :unauthorized,
        :password_settled,
        no_content: "Parent removed",
        forbidden: "Forbidden - requires roles:edit, and holding both roles or being an admin",
        not_found: "Role or parent role not found, or the role does not inherit from it",
        conflict: "A link of the default hierarchy, or it would leave nobody with the admin role"
      ])

  def remove_parent(conn, %{"role_id" => role_id, "parent_id" => parent_id}) do
    with {:ok, role} <- Authorization.fetch_role(role_id),
         {:ok, parent} <- Authorization.fetch_role(parent_id),
         :ok <- Authorization.remove_parent_role(role, parent, actor: current_access(conn)) do
      send_resp(conn, :no_content, "")
    end
  end

  # The ids come from the path, so a cycle is a 409 like a duplicate, not a 422.
  defp conflict_if_cycle({:error, %Ecto.Changeset{errors: errors}} = result) do
    cycle? =
      Enum.any?(errors, fn {_field, {_message, opts}} ->
        opts[:validation] == :cycle or opts[:constraint] == :check
      end)

    if cycle?, do: {:error, :hierarchy_cycle}, else: result
  end

  defp conflict_if_cycle(result), do: result
end
