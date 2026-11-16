# User management (`RephiWeb.UserController`). See `RephiWeb.Schemas`.

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
      required: [:id, :email, :roles, :permissions, :inserted_at, :updated_at]
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
