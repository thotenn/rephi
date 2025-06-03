defmodule RephiWeb.AuthController do
  use RephiWeb, :controller
  use PhoenixSwagger

  alias Rephi.{Accounts, Authorization}
  alias RephiWeb.Auth.Guardian
  alias PhoenixSwagger.Schema
  alias RephiWeb.UserView
  import RephiWeb.ErrorHelpers

  swagger_path :register do
    post("/api/users/register")
    summary("Register a new user")
    description("Creates a new user account and returns authentication token")
    consumes("application/json")
    produces("application/json")

    parameters do
      user(:body, Schema.ref(:UserRegistration), "User registration details", required: true)
    end

    response(201, "User created successfully", Schema.ref(:AuthResponse))

    response(422, "Validation errors", Schema.ref(:ValidationErrors))
  end

  def register(conn, user_params) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        {:ok, token, _claims} = Guardian.encode_and_sign(user)

        conn
        |> put_status(:created)
        |> put_view(UserView)
        |> render("user_with_token.json", user: user, token: token)

      {:error, changeset} ->
        render_changeset_errors(conn, changeset)
    end
  end

  swagger_path :login do
    post("/api/users/login")
    summary("User login")
    description("Authenticates user credentials and returns authentication token")
    consumes("application/json")
    produces("application/json")

    parameters do
      credentials(:body, Schema.ref(:LoginCredentials), "Login credentials", required: true)
    end

    response(200, "Login successful", Schema.ref(:AuthResponse))

    response(401, "Invalid credentials", Schema.ref(:ErrorResponse))
  end

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        {:ok, token, _claims} = Guardian.encode_and_sign(user)

        conn
        |> put_view(UserView)
        |> render("user_with_token.json", user: user, token: token)

      {:error, :invalid_credentials} ->
        render_unauthorized(conn, "Invalid email or password")
    end
  end

  # Catch-all for missing parameters
  def login(conn, _params) do
    render_bad_request(conn, "Email and password are required")
  end

  swagger_path :me do
    get("/api/me")
    summary("Get current user")
    description("Returns the current authenticated user's information")
    produces("application/json")
    security([%{Bearer: []}])

    response(200, "User information", Schema.ref(:UserResponse))

    response(401, "Unauthorized")
  end

  def me(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    roles = Authorization.get_user_roles(user)
    permissions = Authorization.get_user_permissions(user)

    conn
    |> put_view(UserView)
    |> render("me_with_auth.json", user: user, roles: roles, permissions: permissions)
  end

  # Swagger schema definitions
  def swagger_definitions do
    %{
      UserRegistration: %{
        type: :object,
        title: "User Registration",
        description: "New user registration data",
        properties: %{
          email: %{type: :string, description: "User's email address", format: :email},
          password: %{type: :string, description: "User's password", minLength: 8}
        },
        required: [:email, :password],
        example: %{
          email: "admin@admin.com",
          password: "password123!!"
        }
      },
      LoginCredentials: %{
        type: :object,
        title: "Login Credentials",
        description: "User login credentials",
        properties: %{
          email: %{type: :string, description: "User's email address", format: :email},
          password: %{type: :string, description: "User's password"}
        },
        required: [:email, :password],
        example: %{
          email: "admin@admin.com",
          password: "password123!!"
        }
      },
      AuthResponse: %{
        type: :object,
        title: "Authentication Response",
        description: "Successful authentication response",
        properties: %{
          user: %{
            type: :object,
            properties: %{
              id: %{type: :integer, description: "User ID"},
              email: %{type: :string, description: "User's email address"}
            }
          },
          token: %{type: :string, description: "JWT authentication token"}
        },
        required: [:user, :token],
        example: %{
          user: %{
            id: 1,
            email: "user@example.com"
          },
          token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
        }
      },
      UserResponse: %{
        type: :object,
        title: "User Response",
        description: "User information response",
        properties: %{
          user: %{
            type: :object,
            properties: %{
              id: %{type: :integer, description: "User ID"},
              email: %{type: :string, description: "User's email address"}
            }
          }
        },
        required: [:user],
        example: %{
          user: %{
            id: 1,
            email: "user@example.com"
          }
        }
      },
      ErrorResponse: %{
        type: :object,
        title: "Error Response",
        description: "Error response",
        properties: %{
          error: %{type: :string, description: "Error message"}
        },
        required: [:error],
        example: %{
          error: "Invalid email or password"
        }
      },
      ValidationErrors: %{
        type: :object,
        title: "Validation Errors",
        description: "Validation error response",
        properties: %{
          errors: %{type: :object, description: "Validation error messages"}
        },
        required: [:errors],
        example: %{
          errors: %{
            email: ["can't be blank"],
            password: ["should be at least 8 character(s)"]
          }
        }
      }
    }
  end
end
