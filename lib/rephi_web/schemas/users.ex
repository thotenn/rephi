defmodule RephiWeb.Schemas.User do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias RephiWeb.Schemas

  OpenApiSpex.schema(
    %{
      description: "A user, with its assigned roles and direct permissions",
      type: :object,
      properties: %{
        id: %Schema{type: :integer},
        email: %Schema{type: :string},
        must_change_password: %Schema{
          type: :boolean,
          description:
            "Its password was reset by an administrator and it has not set a new one yet"
        },
        roles: %Schema{
          type: :array,
          description: "Roles assigned to the user (not the inherited ones), by slug",
          items: Schemas.Grant
        },
        permissions: %Schema{
          type: :array,
          description: "Permissions granted to the user directly (not through roles), by slug",
          items: Schemas.Grant
        },
        inserted_at: Schemas.timestamp(),
        updated_at: Schemas.timestamp()
      },
      required: [
        :id,
        :email,
        :must_change_password,
        :roles,
        :permissions,
        :inserted_at,
        :updated_at
      ]
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.UsersResponse do
  require OpenApiSpex

  OpenApiSpex.schema(
    RephiWeb.Schemas.page(RephiWeb.Schemas.User,
      description: "One page of users",
      example: %{
        data: [
          %{
            id: 1,
            email: "admin@example.com",
            must_change_password: false,
            roles: [%{id: 1, name: "Administrator", slug: "admin"}],
            permissions: [],
            inserted_at: "2026-01-03T10:00:00Z",
            updated_at: "2026-01-03T10:00:00Z"
          }
        ],
        meta: %{page: 1, page_size: 50, total: 1, total_pages: 1}
      }
    ),
    struct?: false
  )
end

defmodule RephiWeb.Schemas.UserResponse do
  require OpenApiSpex

  OpenApiSpex.schema(
    RephiWeb.Schemas.data(RephiWeb.Schemas.User, description: "A single user"),
    struct?: false
  )
end

defmodule RephiWeb.Schemas.UpdateUserRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "Only the email can change; without it nothing changes",
      type: :object,
      properties: %{
        email: %Schema{type: :string, format: :email, maxLength: 160}
      },
      example: %{email: "someone@example.com"}
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.UserRolesResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    RephiWeb.Schemas.data(
      %Schema{type: :array, items: RephiWeb.Schemas.GrantWithDescription},
      description: "The roles assigned to a user"
    ),
    struct?: false
  )
end

defmodule RephiWeb.Schemas.DirectUserPermission do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "A permission granted to the user itself, with the grant",
      type: :object,
      properties: %{
        id: %Schema{type: :integer},
        name: %Schema{type: :string},
        slug: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        assigned_by: %Schema{
          type: :integer,
          nullable: true,
          description: "The user who granted it (null once that user is deleted)"
        },
        notes: %Schema{type: :string, nullable: true},
        granted_at: RephiWeb.Schemas.timestamp()
      },
      required: [:id, :name, :slug, :description, :assigned_by, :notes, :granted_at]
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.EffectiveUserPermission do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "A permission the user holds, and where it comes from",
      type: :object,
      properties: %{
        id: %Schema{type: :integer},
        name: %Schema{type: :string},
        slug: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        direct: %Schema{type: :boolean, description: "Granted to the user itself"},
        roles: %Schema{
          type: :array,
          description:
            "The roles that grant it, by slug: assigned to the user or inherited through the hierarchy (the role the permission is assigned to); [] when only direct",
          items: RephiWeb.Schemas.Grant
        }
      },
      required: [:id, :name, :slug, :description, :direct, :roles]
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.UserPermissions do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "The direct grants of a user and everything it may do",
      type: :object,
      properties: %{
        direct: %Schema{type: :array, items: RephiWeb.Schemas.DirectUserPermission},
        effective: %Schema{type: :array, items: RephiWeb.Schemas.EffectiveUserPermission}
      },
      required: [:direct, :effective]
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.UserPermissionsResponse do
  require OpenApiSpex

  OpenApiSpex.schema(
    RephiWeb.Schemas.data(RephiWeb.Schemas.UserPermissions,
      description:
        "The permissions granted to a user directly, and everything it may do with the source of each",
      example: %{
        data: %{
          direct: [
            %{
              id: 12,
              name: "Export Reports",
              slug: "reports:export",
              description: nil,
              assigned_by: 1,
              notes: nil,
              granted_at: "2026-01-03T10:00:00Z"
            }
          ],
          effective: [
            %{
              id: 12,
              name: "Export Reports",
              slug: "reports:export",
              description: nil,
              direct: true,
              roles: []
            },
            %{
              id: 1,
              name: "View Users",
              slug: "users:view",
              description: "View user profiles and listings",
              direct: false,
              roles: [%{id: 2, name: "Manager", slug: "manager"}]
            }
          ]
        }
      }
    ),
    struct?: false
  )
end

defmodule RephiWeb.Schemas.PasswordReset do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description:
        "The user, now with must_change_password, and its temporary password (shown once)",
      type: :object,
      properties: %{
        user: RephiWeb.Schemas.User,
        temporary_password: %Schema{
          type: :string,
          minLength: 24,
          maxLength: 24,
          description:
            "Random, 24 characters; valid only to sign in and set a new password. It is not stored and cannot be retrieved again"
        }
      },
      required: [:user, :temporary_password]
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.PasswordResetResponse do
  require OpenApiSpex

  OpenApiSpex.schema(
    RephiWeb.Schemas.data(RephiWeb.Schemas.PasswordReset,
      description:
        "The user, now with must_change_password, and its temporary password (shown once)",
      example: %{
        data: %{
          user: %{
            id: 5,
            email: "someone@example.com",
            must_change_password: true,
            roles: [%{id: 3, name: "User", slug: "user"}],
            permissions: [],
            inserted_at: "2026-01-03T10:00:00Z",
            updated_at: "2026-01-04T09:30:00Z"
          },
          temporary_password: "q3Vt0x9JmZr7KbN2LwYp4sHd"
        }
      }
    ),
    struct?: false
  )
end
