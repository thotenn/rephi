defmodule RephiWeb.Schemas.Permission do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias RephiWeb.Schemas

  OpenApiSpex.schema(
    %{
      description: "A permission",
      type: :object,
      properties: %{
        id: %Schema{type: :integer},
        name: %Schema{type: :string},
        slug: %Schema{type: :string, description: "category:action, unique"},
        description: %Schema{type: :string, nullable: true},
        parent_id: %Schema{
          type: :integer,
          nullable: true,
          description: "Parent permission, for grouping only (holding it grants nothing)"
        },
        is_system: %Schema{
          type: :boolean,
          description: "Part of the application (seeded): cannot be deleted, slug cannot change"
        },
        inserted_at: Schemas.timestamp(),
        updated_at: Schemas.timestamp()
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
    struct?: false
  )
end

defmodule RephiWeb.Schemas.PermissionInput do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "A new permission",
      type: :object,
      properties: %{
        name: %Schema{type: :string, maxLength: 255},
        slug: %Schema{
          type: :string,
          maxLength: 100,
          pattern: "^[a-z0-9]+([_-][a-z0-9]+)*(:[a-z0-9]+([_-][a-z0-9]+)*)+$",
          description: "category:action, unique"
        },
        description: %Schema{type: :string, maxLength: 2000},
        parent_id: %Schema{
          type: :integer,
          nullable: true,
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
    struct?: false
  )
end

defmodule RephiWeb.Schemas.PermissionUpdate do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "The attributes of a permission to change; all optional",
      type: :object,
      properties: %{
        name: %Schema{type: :string, maxLength: 255},
        slug: %Schema{
          type: :string,
          maxLength: 100,
          pattern: "^[a-z0-9]+([_-][a-z0-9]+)*(:[a-z0-9]+([_-][a-z0-9]+)*)+$",
          description: "Cannot change on a system permission"
        },
        description: %Schema{type: :string, maxLength: 2000},
        parent_id: %Schema{
          type: :integer,
          nullable: true,
          description: "Parent permission, for grouping only; not the permission itself"
        }
      },
      example: %{description: "Allows creating and scheduling reports"}
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.PermissionsResponse do
  require OpenApiSpex

  OpenApiSpex.schema(
    RephiWeb.Schemas.page(RephiWeb.Schemas.Permission, description: "One page of permissions"),
    struct?: false
  )
end

defmodule RephiWeb.Schemas.PermissionResponse do
  require OpenApiSpex

  OpenApiSpex.schema(
    RephiWeb.Schemas.data(RephiWeb.Schemas.Permission, description: "A single permission"),
    struct?: false
  )
end

defmodule RephiWeb.Schemas.RolePermissionAssignment do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "The assignment created by giving a permission to a role",
      type: :object,
      properties: %{
        role_id: %Schema{type: :integer},
        permission_id: %Schema{type: :integer},
        assigned_by: %Schema{
          type: :integer,
          nullable: true,
          description: "The user who assigned it (null once that user is deleted)"
        },
        notes: %Schema{type: :string, nullable: true},
        inserted_at: RephiWeb.Schemas.timestamp()
      },
      required: [:role_id, :permission_id, :assigned_by, :notes, :inserted_at]
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.RolePermissionAssignmentResponse do
  require OpenApiSpex

  OpenApiSpex.schema(
    RephiWeb.Schemas.data(RephiWeb.Schemas.RolePermissionAssignment,
      description: "The assignment created by giving a permission to a role"
    ),
    struct?: false
  )
end
