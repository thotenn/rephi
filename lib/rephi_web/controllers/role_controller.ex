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
    * Removing the admin role from its last holder, directly, by deleting
      a role that inherits from it or by unlinking such a role from it,
      answers `409`.
    * Linking or unlinking a parent requires holding both roles, or being an
      admin (`403`); cycles, duplicates and system links are `409`.

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
  use PhoenixSwagger

  import RephiWeb.Swagger

  alias PhoenixSwagger.Schema
  alias Rephi.Accounts
  alias Rephi.Authorization
  alias Rephi.Authorization.{Role, RoleRole}

  action_fallback RephiWeb.FallbackController

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

  swagger_path :index do
    get("/api/roles")
    summary("List roles")
    description("One page of roles, ordered by slug. Requires roles:view.")
    tag("Roles")
    produces("application/json")
    bearer_auth()
    page_params()
    response(200, "One page of roles", Schema.ref(:RolesResponse))
    error_response(403, "Forbidden - requires roles:view")
  end

  def index(conn, params) do
    with {:ok, page} <- Authorization.paginate_roles(params) do
      render(conn, :index, page: page)
    end
  end

  swagger_path :show do
    get("/api/roles/{id}")
    summary("Get a role")

    description(
      "A role with the permissions assigned to it (permissions) and the ones it only inherits from its parent roles (inherited_permissions). Requires roles:view."
    )

    tag("Roles")
    produces("application/json")
    bearer_auth()
    id_param(:id, "Role ID")
    response(200, "The role", Schema.ref(:RoleDetailResponse))
    error_response(403, "Forbidden - requires roles:view")
    error_response(404, "Role not found")
  end

  def show(conn, %{"id" => id}) do
    with {:ok, role} <- Authorization.fetch_role(id) do
      render(conn, :show, role: role, sources: Authorization.get_role_permission_sources(role))
    end
  end

  swagger_path :create do
    post("/api/roles")
    summary("Create a role")

    description(
      "The attributes may also be wrapped under \"role\". Requires roles:create. The location header points to the new role."
    )

    tag("Roles")
    consumes("application/json")
    produces("application/json")
    bearer_auth()

    parameters do
      body(:body, Schema.ref(:RoleInput), "The role", required: true)
    end

    response(201, "Role created", Schema.ref(:RoleDetailResponse))
    body_errors()
    error_response(403, "Forbidden - requires roles:create")
    validation_response("Invalid or taken name or slug")
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
    summary("Update a role")

    description(
      "Changes the attributes sent; the others keep their value. The attributes may also be wrapped under \"role\". The slug of a system role cannot change (422). PUT and PATCH behave the same. Requires roles:edit."
    )

    tag("Roles")
    consumes("application/json")
    produces("application/json")
    bearer_auth()
    id_param(:id, "Role ID")

    parameters do
      body(:body, Schema.ref(:RoleUpdate), "The attributes to change", required: true)
    end

    response(200, "Role updated", Schema.ref(:RoleDetailResponse))
    body_errors()
    error_response(403, "Forbidden - requires roles:edit")
    error_response(404, "Role not found")
    validation_response("Invalid or taken name or slug, or the slug of a system role")
  end

  defoverridable swagger_path_update: 1
  def swagger_path_update(route), do: route |> super() |> operation_per_verb()

  def update(conn, %{"id" => id}) do
    with {:ok, role} <- Authorization.fetch_role(id),
         {:ok, %Role{} = role} <- Authorization.update_role(role, resource_params(conn, "role")) do
      render(conn, :show, role: role, sources: Authorization.get_role_permission_sources(role))
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/roles/{id}")
    summary("Delete a role")
    description("Requires roles:delete.")
    tag("Roles")
    produces("application/json")
    bearer_auth()
    id_param(:id, "Role ID")
    response(204, "Role deleted")
    error_response(403, "Forbidden - requires roles:delete")
    error_response(404, "Role not found")

    error_response(
      409,
      "A system role, or deleting it would leave nobody with the admin role"
    )
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, role} <- Authorization.fetch_role(id),
         {:ok, %Role{}} <- Authorization.delete_role(role) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :assign_to_user do
    post("/api/users/{user_id}/roles/{role_id}")
    summary("Assign a role to a user")

    description(
      "Requires roles:assign, and holding the role (assigned or inherited) or being an admin. The body is optional. assigned_by is the caller."
    )

    tag("Roles")
    consumes("application/json")
    produces("application/json")
    bearer_auth()
    id_param(:user_id, "User ID")
    id_param(:role_id, "Role ID")

    parameters do
      body(:body, Schema.ref(:AssignmentNotes), "Optional notes", required: false)
    end

    response(201, "Role assigned", Schema.ref(:UserRoleAssignmentResponse))
    body_errors()

    error_response(
      403,
      "Forbidden - requires roles:assign, and holding the role or being an admin"
    )

    error_response(404, "User or role not found")
    error_response(409, "Role already assigned to user")
    validation_response("notes is not a string or is too long")
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
    summary("Remove a role from a user")

    description(
      "Requires roles:assign, and holding the role (assigned or inherited) or being an admin."
    )

    tag("Roles")
    produces("application/json")
    bearer_auth()
    id_param(:user_id, "User ID")
    id_param(:role_id, "Role ID")
    response(204, "Role removed")

    error_response(
      403,
      "Forbidden - requires roles:assign, and holding the role or being an admin"
    )

    error_response(404, "User or role not found, or the role is not assigned to the user")
    error_response(409, "It would leave nobody with the admin role")
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
    summary("List the permissions of a role")

    description(
      "Every permission the role grants, by slug: assigned to it (inherited: false) or inherited from its parent roles (inherited: true, inherited_from lists them). Not paginated. Requires roles:view."
    )

    tag("Roles")
    produces("application/json")
    bearer_auth()
    id_param(:id, "Role ID")
    response(200, "The permissions of the role", Schema.ref(:RolePermissionsResponse))
    error_response(403, "Forbidden - requires roles:view")
    error_response(404, "Role not found")
  end

  def get_role_permissions(conn, %{"id" => id}) do
    with {:ok, role} <- Authorization.fetch_role(id) do
      render(conn, :permissions, sources: Authorization.get_role_permission_sources(role))
    end
  end

  swagger_path :get_role_parents do
    get("/api/roles/{id}/parents")
    summary("List the parent roles of a role")

    description(
      "The roles this role inherits from directly (not their own ancestors; the permissions inherited through the whole chain are in inherited_permissions of GET /api/roles/{id}), by slug, each with its link. Not paginated. Requires roles:view."
    )

    tag("Roles")
    produces("application/json")
    bearer_auth()
    id_param(:id, "Role ID")
    response(200, "The parent roles", Schema.ref(:RoleLinksResponse))
    error_response(403, "Forbidden - requires roles:view")
    error_response(404, "Role not found")
  end

  def get_role_parents(conn, %{"id" => id}) do
    with {:ok, role} <- Authorization.fetch_role(id) do
      render(conn, :links, links: Authorization.list_parent_roles(role))
    end
  end

  swagger_path :get_role_children do
    get("/api/roles/{id}/children")
    summary("List the child roles of a role")

    description(
      "The roles that inherit from this role directly, by slug, each with its link. Not paginated. Requires roles:view."
    )

    tag("Roles")
    produces("application/json")
    bearer_auth()
    id_param(:id, "Role ID")
    response(200, "The child roles", Schema.ref(:RoleLinksResponse))
    error_response(403, "Forbidden - requires roles:view")
    error_response(404, "Role not found")
  end

  def get_role_children(conn, %{"id" => id}) do
    with {:ok, role} <- Authorization.fetch_role(id) do
      render(conn, :links, links: Authorization.list_child_roles(role))
    end
  end

  swagger_path :add_parent do
    post("/api/roles/{role_id}/parents/{parent_id}")
    summary("Make a role inherit from another")

    description(
      "Links parent_id as a parent of role_id: every holder of role_id gets the permissions of parent_id and of its ancestors. Requires roles:edit, and holding both roles (assigned or inherited) or being an admin. The body is optional. assigned_by is the caller. Refused (409) when it would make a role inherit from itself (parent_id is role_id or one of its descendants) or the parent is already linked."
    )

    tag("Roles")
    consumes("application/json")
    produces("application/json")
    bearer_auth()
    id_param(:role_id, "Role ID (the child)")
    id_param(:parent_id, "Parent role ID")

    parameters do
      body(:body, Schema.ref(:AssignmentNotes), "Optional notes", required: false)
    end

    response(201, "Parent linked", Schema.ref(:RoleParentAssignmentResponse))
    body_errors()

    error_response(
      403,
      "Forbidden - requires roles:edit, and holding both roles or being an admin"
    )

    error_response(404, "Role or parent role not found")

    error_response(
      409,
      "The role would inherit from itself, or the parent is already linked"
    )

    validation_response("notes is not a string or is too long")
  end

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

  swagger_path :remove_parent do
    PhoenixSwagger.Path.delete("/api/roles/{role_id}/parents/{parent_id}")
    summary("Remove a parent from a role")

    description(
      "role_id stops inheriting from parent_id. Requires roles:edit, and holding both roles (assigned or inherited) or being an admin. The links of the default hierarchy (is_system) cannot be removed, nor a link through which the last admins hold the admin role (409)."
    )

    tag("Roles")
    produces("application/json")
    bearer_auth()
    id_param(:role_id, "Role ID (the child)")
    id_param(:parent_id, "Parent role ID")
    response(204, "Parent removed")

    error_response(
      403,
      "Forbidden - requires roles:edit, and holding both roles or being an admin"
    )

    error_response(404, "Role or parent role not found, or the role does not inherit from it")

    error_response(
      409,
      "A link of the default hierarchy, or it would leave nobody with the admin role"
    )
  end

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

  # Swagger schema definitions
  def swagger_definitions do
    RephiWeb.Swagger.definitions(%{
      RoleLink: %{
        type: :object,
        title: "Role Link",
        description:
          "A role linked to another one in the hierarchy (one of its parents or children), with the attributes of the link",
        properties: %{
          id: %{type: :integer, description: "The linked role"},
          name: %{type: :string},
          slug: %{type: :string},
          description: %{type: :string, "x-nullable": true},
          is_system: %{type: :boolean, description: "The linked role is a system role"},
          system_link: %{
            type: :boolean,
            description: "The link is part of the default hierarchy: it cannot be removed"
          },
          assigned_by: %{
            type: :integer,
            "x-nullable": true,
            description:
              "The user who made the link (null for seeded links and once that user is deleted)"
          },
          notes: %{type: :string, "x-nullable": true},
          linked_at: %{type: :string, format: :"date-time"}
        },
        required: [
          :id,
          :name,
          :slug,
          :description,
          :is_system,
          :system_link,
          :assigned_by,
          :notes,
          :linked_at
        ],
        example: %{
          id: 3,
          name: "User",
          slug: "user",
          description: "Basic user access",
          is_system: true,
          system_link: true,
          assigned_by: nil,
          notes: nil,
          linked_at: "2026-01-03T10:00:00Z"
        }
      },
      RoleLinksResponse: %{
        type: :object,
        title: "Role Links Response",
        description: "The parents or the children of a role, by slug",
        properties: %{
          data: %{type: :array, items: Schema.ref(:RoleLink)}
        },
        required: [:data]
      },
      RoleParentAssignmentResponse: %{
        type: :object,
        title: "Role Parent Assignment Response",
        description: "The link created by making a role inherit from another",
        properties: %{
          data: %{
            type: :object,
            properties: %{
              role_id: %{type: :integer, description: "The child role"},
              parent_id: %{type: :integer, description: "The parent role"},
              is_system: %{
                type: :boolean,
                description: "Part of the default hierarchy (always false for a new link)"
              },
              assigned_by: %{
                type: :integer,
                "x-nullable": true,
                description: "The user who made the link (null once that user is deleted)"
              },
              notes: %{type: :string, "x-nullable": true},
              inserted_at: %{type: :string, format: :"date-time"}
            },
            required: [:role_id, :parent_id, :is_system, :assigned_by, :notes, :inserted_at]
          }
        },
        required: [:data],
        example: %{
          data: %{
            role_id: 7,
            parent_id: 2,
            is_system: false,
            assigned_by: 1,
            notes: nil,
            inserted_at: "2026-01-03T10:00:00Z"
          }
        }
      },
      Role: %{
        type: :object,
        title: "Role",
        properties: %{
          id: %{type: :integer},
          name: %{type: :string},
          slug: %{type: :string, description: "Unique identifier"},
          description: %{type: :string, "x-nullable": true},
          is_system: %{
            type: :boolean,
            description: "Part of the application (seeded): cannot be deleted, slug cannot change"
          },
          inserted_at: %{type: :string, format: :"date-time"},
          updated_at: %{type: :string, format: :"date-time"}
        },
        required: [:id, :name, :slug, :description, :is_system, :inserted_at, :updated_at],
        example: %{
          id: 2,
          name: "Manager",
          slug: "manager",
          description: "Can manage users and view reports",
          is_system: true,
          inserted_at: "2026-01-03T10:00:00Z",
          updated_at: "2026-01-03T10:00:00Z"
        }
      },
      RoleInput: %{
        type: :object,
        title: "Role Input",
        description: "A new role",
        properties: %{
          name: %{type: :string, maxLength: 255},
          slug: %{
            type: :string,
            maxLength: 100,
            pattern: "^[a-z0-9]+([_-][a-z0-9]+)*$",
            description: "Unique identifier"
          },
          description: %{type: :string, maxLength: 2000}
        },
        required: [:name, :slug],
        example: %{
          name: "Content Editor",
          slug: "content_editor",
          description: "Can create and edit content"
        }
      },
      RoleUpdate: %{
        type: :object,
        title: "Role Update",
        description: "The attributes of a role to change; all optional",
        properties: %{
          name: %{type: :string, maxLength: 255},
          slug: %{
            type: :string,
            maxLength: 100,
            pattern: "^[a-z0-9]+([_-][a-z0-9]+)*$",
            description: "Cannot change on a system role"
          },
          description: %{type: :string, maxLength: 2000}
        },
        example: %{name: "Senior Editor"}
      },
      RolesResponse: %{
        type: :object,
        title: "Roles Response",
        description: "One page of roles",
        properties: %{
          data: %{type: :array, items: Schema.ref(:Role)},
          meta: Schema.ref(:PageMeta)
        },
        required: [:data, :meta]
      },
      InheritedPermission: %{
        type: :object,
        title: "Inherited Permission",
        description: "A permission a role inherits from its parent roles",
        properties: %{
          id: %{type: :integer},
          name: %{type: :string},
          slug: %{type: :string},
          description: %{type: :string, "x-nullable": true},
          inherited_from: %{
            type: :array,
            description: "The ancestor roles that grant it",
            items: Schema.ref(:Grant)
          }
        },
        required: [:id, :name, :slug, :description, :inherited_from]
      },
      RoleDetailResponse: %{
        type: :object,
        title: "Role Detail Response",
        description:
          "A role with the permissions assigned to it and the ones it only inherits (not assigned to it)",
        properties: %{
          data: %{
            type: :object,
            properties: %{
              id: %{type: :integer},
              name: %{type: :string},
              slug: %{type: :string},
              description: %{type: :string, "x-nullable": true},
              is_system: %{type: :boolean},
              inserted_at: %{type: :string, format: :"date-time"},
              updated_at: %{type: :string, format: :"date-time"},
              permissions: %{
                type: :array,
                description: "Assigned to the role itself (removable), by slug",
                items: Schema.ref(:GrantWithDescription)
              },
              inherited_permissions: %{
                type: :array,
                description: "Inherited from parent roles only (read-only here), by slug",
                items: Schema.ref(:InheritedPermission)
              }
            },
            required: [
              :id,
              :name,
              :slug,
              :description,
              :is_system,
              :inserted_at,
              :updated_at,
              :permissions,
              :inherited_permissions
            ]
          }
        },
        required: [:data],
        example: %{
          data: %{
            id: 1,
            name: "Administrator",
            slug: "admin",
            description: "Full system access",
            is_system: true,
            inserted_at: "2026-01-03T10:00:00Z",
            updated_at: "2026-01-03T10:00:00Z",
            permissions: [
              %{
                id: 12,
                name: "Broadcast Notifications",
                slug: "notifications:broadcast",
                description: nil
              }
            ],
            inherited_permissions: [
              %{
                id: 5,
                name: "View Roles",
                slug: "roles:view",
                description: nil,
                inherited_from: [%{id: 2, name: "Manager", slug: "manager"}]
              }
            ]
          }
        }
      },
      AssignmentNotes: %{
        type: :object,
        title: "Assignment Notes",
        description: "Optional notes kept with an assignment",
        properties: %{
          notes: %{type: :string, maxLength: 2000}
        },
        example: %{notes: "Covers for the team lead in March"}
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
              assigned_by: %{
                type: :integer,
                "x-nullable": true,
                description: "The user who assigned it (null once that user is deleted)"
              },
              notes: %{type: :string, "x-nullable": true},
              inserted_at: %{type: :string, format: :"date-time"}
            },
            required: [:user_id, :role_id, :assigned_by, :notes, :inserted_at]
          }
        },
        required: [:data]
      },
      RolePermissionsResponse: %{
        type: :object,
        title: "Role Permissions Response",
        description: "Every permission the role grants, assigned or inherited, by slug",
        properties: %{
          data: %{
            type: :array,
            items: %{
              type: :object,
              properties: %{
                id: %{type: :integer},
                name: %{type: :string},
                slug: %{type: :string},
                description: %{type: :string, "x-nullable": true},
                inherited: %{
                  type: :boolean,
                  description: "Not assigned to the role, only inherited"
                },
                inherited_from: %{
                  type: :array,
                  description: "The ancestor roles that grant it ([] when assigned)",
                  items: Schema.ref(:Grant)
                }
              },
              required: [:id, :name, :slug, :description, :inherited, :inherited_from]
            }
          }
        },
        required: [:data]
      }
    })
  end
end
