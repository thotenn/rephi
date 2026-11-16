defmodule RephiWeb.Schemas.Role do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias RephiWeb.Schemas

  OpenApiSpex.schema(
    %{
      description: "A role",
      type: :object,
      properties: %{
        id: %Schema{type: :integer},
        name: %Schema{type: :string},
        slug: %Schema{type: :string, description: "Unique identifier"},
        description: %Schema{type: :string, nullable: true},
        is_system: %Schema{
          type: :boolean,
          description: "Part of the application (seeded): cannot be deleted, slug cannot change"
        },
        inserted_at: Schemas.timestamp(),
        updated_at: Schemas.timestamp()
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
    struct?: false
  )
end

defmodule RephiWeb.Schemas.RoleInput do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "A new role",
      type: :object,
      properties: %{
        name: %Schema{type: :string, maxLength: 255},
        slug: %Schema{
          type: :string,
          maxLength: 100,
          pattern: "^[a-z0-9]+([_-][a-z0-9]+)*$",
          description: "Unique identifier"
        },
        description: %Schema{type: :string, maxLength: 2000}
      },
      required: [:name, :slug],
      example: %{
        name: "Content Editor",
        slug: "content_editor",
        description: "Can create and edit content"
      }
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.RoleUpdate do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "The attributes of a role to change; all optional",
      type: :object,
      properties: %{
        name: %Schema{type: :string, maxLength: 255},
        slug: %Schema{
          type: :string,
          maxLength: 100,
          pattern: "^[a-z0-9]+([_-][a-z0-9]+)*$",
          description: "Cannot change on a system role"
        },
        description: %Schema{type: :string, maxLength: 2000}
      },
      example: %{name: "Senior Editor"}
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.RolesResponse do
  require OpenApiSpex

  OpenApiSpex.schema(
    RephiWeb.Schemas.page(RephiWeb.Schemas.Role, description: "One page of roles"),
    struct?: false
  )
end

defmodule RephiWeb.Schemas.InheritedPermission do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "A permission a role inherits from its parent roles",
      type: :object,
      properties: %{
        id: %Schema{type: :integer},
        name: %Schema{type: :string},
        slug: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        inherited_from: %Schema{
          type: :array,
          description: "The ancestor roles that grant it",
          items: RephiWeb.Schemas.Grant
        }
      },
      required: [:id, :name, :slug, :description, :inherited_from]
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.RoleDetail do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias RephiWeb.Schemas

  OpenApiSpex.schema(
    %{
      description:
        "A role with the permissions assigned to it and the ones it only inherits (not assigned to it)",
      type: :object,
      properties: %{
        id: %Schema{type: :integer},
        name: %Schema{type: :string},
        slug: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        is_system: %Schema{type: :boolean},
        inserted_at: Schemas.timestamp(),
        updated_at: Schemas.timestamp(),
        permissions: %Schema{
          type: :array,
          description: "Assigned to the role itself (removable), by slug",
          items: Schemas.GrantWithDescription
        },
        inherited_permissions: %Schema{
          type: :array,
          description: "Inherited from parent roles only (read-only here), by slug",
          items: Schemas.InheritedPermission
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
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.RoleDetailResponse do
  require OpenApiSpex

  OpenApiSpex.schema(
    RephiWeb.Schemas.data(RephiWeb.Schemas.RoleDetail,
      description: "A role with its assigned and inherited permissions",
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
    ),
    struct?: false
  )
end

defmodule RephiWeb.Schemas.UserRoleAssignment do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "The assignment created by giving a role to a user",
      type: :object,
      properties: %{
        user_id: %Schema{type: :integer},
        role_id: %Schema{type: :integer},
        assigned_by: %Schema{
          type: :integer,
          nullable: true,
          description: "The user who assigned it (null once that user is deleted)"
        },
        notes: %Schema{type: :string, nullable: true},
        inserted_at: RephiWeb.Schemas.timestamp()
      },
      required: [:user_id, :role_id, :assigned_by, :notes, :inserted_at]
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.UserRoleAssignmentResponse do
  require OpenApiSpex

  OpenApiSpex.schema(
    RephiWeb.Schemas.data(RephiWeb.Schemas.UserRoleAssignment,
      description: "The assignment created by giving a role to a user"
    ),
    struct?: false
  )
end

defmodule RephiWeb.Schemas.RolePermissionEntry do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "A permission a role grants, assigned to it or inherited",
      type: :object,
      properties: %{
        id: %Schema{type: :integer},
        name: %Schema{type: :string},
        slug: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        inherited: %Schema{
          type: :boolean,
          description: "Not assigned to the role, only inherited"
        },
        inherited_from: %Schema{
          type: :array,
          description: "The ancestor roles that grant it ([] when assigned)",
          items: RephiWeb.Schemas.Grant
        }
      },
      required: [:id, :name, :slug, :description, :inherited, :inherited_from]
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.RolePermissionsResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    RephiWeb.Schemas.data(
      %Schema{type: :array, items: RephiWeb.Schemas.RolePermissionEntry},
      description: "Every permission the role grants, assigned or inherited, by slug"
    ),
    struct?: false
  )
end

defmodule RephiWeb.Schemas.RoleLink do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description:
        "A role linked to another one in the hierarchy (one of its parents or children), with the attributes of the link",
      type: :object,
      properties: %{
        id: %Schema{type: :integer, description: "The linked role"},
        name: %Schema{type: :string},
        slug: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        is_system: %Schema{type: :boolean, description: "The linked role is a system role"},
        system_link: %Schema{
          type: :boolean,
          description: "The link is part of the default hierarchy: it cannot be removed"
        },
        assigned_by: %Schema{
          type: :integer,
          nullable: true,
          description:
            "The user who made the link (null for seeded links and once that user is deleted)"
        },
        notes: %Schema{type: :string, nullable: true},
        linked_at: RephiWeb.Schemas.timestamp()
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
    struct?: false
  )
end

defmodule RephiWeb.Schemas.RoleLinksResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    RephiWeb.Schemas.data(
      %Schema{type: :array, items: RephiWeb.Schemas.RoleLink},
      description: "The parents or the children of a role, by slug"
    ),
    struct?: false
  )
end

defmodule RephiWeb.Schemas.RoleParentAssignment do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "The link created by making a role inherit from another",
      type: :object,
      properties: %{
        role_id: %Schema{type: :integer, description: "The child role"},
        parent_id: %Schema{type: :integer, description: "The parent role"},
        is_system: %Schema{
          type: :boolean,
          description: "Part of the default hierarchy (always false for a new link)"
        },
        assigned_by: %Schema{
          type: :integer,
          nullable: true,
          description: "The user who made the link (null once that user is deleted)"
        },
        notes: %Schema{type: :string, nullable: true},
        inserted_at: RephiWeb.Schemas.timestamp()
      },
      required: [:role_id, :parent_id, :is_system, :assigned_by, :notes, :inserted_at]
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.RoleParentAssignmentResponse do
  require OpenApiSpex

  OpenApiSpex.schema(
    RephiWeb.Schemas.data(RephiWeb.Schemas.RoleParentAssignment,
      description: "The link created by making a role inherit from another",
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
    ),
    struct?: false
  )
end
