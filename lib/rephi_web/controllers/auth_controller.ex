defmodule RephiWeb.AuthController do
  @moduledoc """
  Registration, login, logout and the "who am I" endpoint.

  ## Endpoints

    * `POST /api/users/register` - Create an account and get a token
    * `POST /api/users/login` - Exchange credentials for a token
    * `POST /api/users/logout` - Revoke every token of the signed-in user
    * `GET /api/me` - The signed-in user with roles and permissions
    * `PUT /api/me/password` - Change the password of the signed-in user

  A new account gets the default role (`Rephi.Accounts.register_user/1`).
  The user in every response carries the roles assigned to it and its
  effective permissions, from `Rephi.Authorization.load_access/1`: one query,
  shared with the claims of the token.

  Register and login accept their attributes flat (`{"email": ..., "password": ...}`)
  or wrapped under `"user"`. Both are throttled per client IP
  (`RephiWeb.Plugs.RateLimit`): past the limit they answer `429` with a
  `retry-after` header.
  """
  use RephiWeb, :controller
  use PhoenixSwagger

  alias PhoenixSwagger.Schema
  alias Rephi.Accounts
  alias Rephi.Authorization
  alias RephiWeb.Auth.Guardian

  action_fallback RephiWeb.FallbackController

  plug RephiWeb.Plugs.RateLimit, [bucket: :register] when action == :register
  # Checking the current password is as good a password oracle as login.
  plug RephiWeb.Plugs.RateLimit, [bucket: :login] when action in [:login, :change_password]

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
    response(429, "Too many attempts, see the retry-after header", Schema.ref(:ErrorResponse))
  end

  def register(conn, _params) do
    with {:ok, user} <- Accounts.register_user(resource_params(conn, "user")) do
      conn
      |> put_status(:created)
      |> render_session(user)
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

    response(400, "Email or password missing", Schema.ref(:ErrorResponse))
    response(401, "Invalid credentials", Schema.ref(:ErrorResponse))
    response(429, "Too many attempts, see the retry-after header", Schema.ref(:ErrorResponse))
  end

  def login(conn, _params) do
    with {:ok, email, password} <- credentials(resource_params(conn, "user")),
         {:ok, user} <- authenticate(email, password) do
      render_session(conn, user)
    end
  end

  swagger_path :logout do
    post("/api/users/logout")
    summary("Log out")

    description(
      "Revokes every token issued to the signed-in user (on all devices) and closes its WebSocket connections"
    )

    security([%{Bearer: []}])

    response(204, "Logged out")
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
  end

  def logout(conn, _params) do
    with {:ok, _user} <- Accounts.revoke_tokens(conn.assigns.current_user) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :me do
    get("/api/me")
    summary("Get current user")
    description("Returns the current authenticated user's information")
    produces("application/json")
    security([%{Bearer: []}])

    response(200, "User information", Schema.ref(:MeResponse))

    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
  end

  def me(conn, _params) do
    render(conn, :me, user: conn.assigns.current_user, access: current_access(conn))
  end

  swagger_path :change_password do
    put("/api/me/password")
    summary("Change my password")

    description(
      "Sets a new password for the signed-in user, who must send the current one. Every token issued before is revoked and the user's WebSocket connections are closed; the response carries a new token."
    )

    consumes("application/json")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      body(:body, Schema.ref(:PasswordChange), "Current and new password", required: true)
    end

    response(200, "Password changed, new session", Schema.ref(:AuthResponse))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(422, "Wrong current password or invalid new one", Schema.ref(:ValidationErrors))
    response(429, "Too many attempts, see the retry-after header", Schema.ref(:ErrorResponse))
  end

  def change_password(conn, _params) do
    params = resource_params(conn, "user")

    with {:ok, user} <-
           Accounts.change_password(
             conn.assigns.current_user,
             params["current_password"],
             Map.take(params, ["password", "password_confirmation"])
           ) do
      render_session(conn, user)
    end
  end

  defp credentials(%{"email" => email, "password" => password})
       when is_binary(email) and is_binary(password) do
    {:ok, email, password}
  end

  defp credentials(_params), do: {:error, :bad_request, "Email and password are required"}

  defp authenticate(email, password) do
    with {:error, :invalid_credentials} <- Accounts.authenticate_user(email, password) do
      {:error, :unauthorized, "Invalid email or password"}
    end
  end

  defp render_session(conn, user) do
    access = Authorization.load_access(user)
    {:ok, token, _claims} = Guardian.encode_and_sign(user, %{}, access: access)
    render(conn, :session, token: token, user: user, access: access)
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
          password: %{
            type: :string,
            description: "User's password (8 characters minimum, 72 bytes maximum)",
            minLength: 8
          }
        },
        required: [:email, :password],
        example: %{
          email: "user@example.com",
          password: "a-long-passphrase"
        }
      },
      PasswordChange: %{
        type: :object,
        title: "Password Change",
        description: "The current password and the new one",
        properties: %{
          current_password: %{type: :string},
          password: %{type: :string, minLength: 8, description: "8 characters to 72 bytes"},
          password_confirmation: %{type: :string, description: "Optional; must match"}
        },
        required: [:current_password, :password],
        example: %{current_password: "a-long-passphrase", password: "another-passphrase"}
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
          email: "user@example.com",
          password: "a-long-passphrase"
        }
      },
      SessionUser: %{
        type: :object,
        title: "Session User",
        description:
          "The signed-in user with the roles assigned to it and its effective permissions (direct, through roles, inherited)",
        properties: %{
          id: %{type: :integer, description: "User ID"},
          email: %{type: :string, description: "User's email address"},
          roles: %{type: :array, items: Schema.ref(:SessionGrant)},
          permissions: %{type: :array, items: Schema.ref(:SessionGrant)}
        },
        required: [:id, :email, :roles, :permissions],
        example: %{
          id: 1,
          email: "user@example.com",
          roles: [%{id: 1, name: "Administrator", slug: "admin"}],
          permissions: [%{id: 1, name: "View Users", slug: "users:view"}]
        }
      },
      SessionGrant: %{
        type: :object,
        title: "Session Grant",
        description: "A role or permission held by the signed-in user",
        properties: %{
          id: %{type: :integer},
          name: %{type: :string},
          slug: %{type: :string}
        },
        required: [:id, :name, :slug]
      },
      AuthResponse: %{
        type: :object,
        title: "Authentication Response",
        description: "Successful authentication response",
        properties: %{
          data: %{
            type: :object,
            properties: %{
              user: Schema.ref(:SessionUser),
              token: %{type: :string, description: "JWT authentication token"}
            },
            required: [:user, :token]
          }
        },
        required: [:data],
        example: %{
          data: %{
            user: %{id: 1, email: "user@example.com", roles: [], permissions: []},
            token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
          }
        }
      },
      MeResponse: %{
        type: :object,
        title: "Current User Response",
        description: "The signed-in user",
        properties: %{
          data: %{
            type: :object,
            properties: %{user: Schema.ref(:SessionUser)},
            required: [:user]
          }
        },
        required: [:data]
      },
      ErrorResponse: %{
        type: :object,
        title: "Error Response",
        description: "Error envelope used by every non-validation error of the API",
        properties: %{
          errors: %{
            type: :object,
            properties: %{
              detail: %{type: :string, description: "Human readable error message"}
            },
            required: [:detail]
          }
        },
        required: [:errors],
        example: %{
          errors: %{detail: "Invalid email or password"}
        }
      },
      ValidationErrors: %{
        type: :object,
        title: "Validation Errors",
        description: "Validation error envelope: one list of messages per invalid field",
        properties: %{
          errors: %{
            type: :object,
            description: "Validation error messages keyed by field",
            additionalProperties: %{type: :array, items: %{type: :string}}
          }
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
