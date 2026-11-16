# Registration, login, the session and the signed-in user
# (`RephiWeb.AuthController`). See `RephiWeb.Schemas`.

defmodule RephiWeb.Schemas.UserRegistration do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "A new account",
      type: :object,
      properties: %{
        email: %Schema{
          type: :string,
          format: :email,
          maxLength: 160,
          description: "Stored trimmed and lowercased; unique regardless of case"
        },
        password: %Schema{
          type: :string,
          minLength: 8,
          description: "8 characters minimum, 72 bytes maximum"
        },
        password_confirmation: %Schema{
          type: :string,
          description: "Optional; must match password"
        }
      },
      required: [:email, :password],
      example: %{email: "user@example.com", password: "a-long-passphrase"}
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.LoginCredentials do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "Email (any case) and password",
      type: :object,
      properties: %{
        email: %Schema{type: :string, format: :email},
        password: %Schema{type: :string}
      },
      required: [:email, :password],
      example: %{email: "user@example.com", password: "a-long-passphrase"}
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.PasswordChange do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "The current password and the new one",
      type: :object,
      properties: %{
        current_password: %Schema{type: :string},
        password: %Schema{
          type: :string,
          minLength: 8,
          description: "8 characters minimum, 72 bytes maximum"
        },
        password_confirmation: %Schema{
          type: :string,
          description: "Optional; must match password"
        }
      },
      required: [:current_password, :password],
      example: %{current_password: "a-long-passphrase", password: "another-passphrase"}
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.SessionUser do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias RephiWeb.Schemas.Grant

  OpenApiSpex.schema(
    %{
      description:
        "The signed-in user: the roles assigned to it (not the inherited ones) and its effective permissions (direct, through roles and inherited), by slug",
      type: :object,
      properties: %{
        id: %Schema{type: :integer},
        email: %Schema{type: :string},
        roles: %Schema{type: :array, items: Grant},
        permissions: %Schema{type: :array, items: Grant}
      },
      required: [:id, :email, :roles, :permissions],
      example: %{
        id: 2,
        email: "user@example.com",
        roles: [%{id: 3, name: "User", slug: "user"}],
        permissions: []
      }
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.Session do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "The user and the access token to send as a Bearer token",
      type: :object,
      properties: %{
        user: RephiWeb.Schemas.SessionUser,
        token: %Schema{type: :string, description: "JWT access token (24 hours by default)"}
      },
      required: [:user, :token]
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.AuthResponse do
  require OpenApiSpex

  OpenApiSpex.schema(
    RephiWeb.Schemas.data(RephiWeb.Schemas.Session,
      description: "A new session: the user and the access token to send as a Bearer token",
      example: %{
        data: %{
          user: %{
            id: 2,
            email: "user@example.com",
            roles: [%{id: 3, name: "User", slug: "user"}],
            permissions: []
          },
          token: "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9..."
        }
      }
    ),
    struct?: false
  )
end

defmodule RephiWeb.Schemas.MeResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    RephiWeb.Schemas.data(
      %Schema{
        type: :object,
        properties: %{user: RephiWeb.Schemas.SessionUser},
        required: [:user]
      },
      description: "The signed-in user"
    ),
    struct?: false
  )
end
