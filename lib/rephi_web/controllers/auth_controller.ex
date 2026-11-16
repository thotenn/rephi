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

  import RephiWeb.Swagger

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

    description(
      "Creates an account with the default role (user) and returns a session. The attributes may also be wrapped under \"user\". Rate limited per client IP."
    )

    tag("Auth")
    consumes("application/json")
    produces("application/json")

    parameters do
      body(:body, Schema.ref(:UserRegistration), "Email and password", required: true)
    end

    response(201, "Account created, new session", Schema.ref(:AuthResponse))
    body_errors()
    validation_response("Invalid or taken email, or invalid password")
    rate_limited()
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
    summary("Log in")

    description(
      "Exchanges credentials for a session. The attributes may also be wrapped under \"user\". Rate limited per client IP."
    )

    tag("Auth")
    consumes("application/json")
    produces("application/json")

    parameters do
      body(:body, Schema.ref(:LoginCredentials), "Email and password", required: true)
    end

    response(200, "Logged in, new session", Schema.ref(:AuthResponse))
    body_errors()
    error_response(400, "Malformed JSON body, or email or password missing or not a string")
    error_response(401, "Invalid email or password")
    rate_limited()
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
      "Revokes every token issued to the signed-in user (on all devices) and closes its WebSocket connections. No body."
    )

    tag("Auth")
    bearer_auth()
    response(204, "Logged out")
  end

  def logout(conn, _params) do
    with {:ok, _user} <- Accounts.revoke_tokens(conn.assigns.current_user) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :me do
    get("/api/me")
    summary("Get the signed-in user")
    description("The signed-in user with the roles assigned to it and its effective permissions")
    tag("Auth")
    produces("application/json")
    bearer_auth()
    response(200, "The signed-in user", Schema.ref(:MeResponse))
  end

  def me(conn, _params) do
    render(conn, :me, user: conn.assigns.current_user, access: current_access(conn))
  end

  swagger_path :change_password do
    put("/api/me/password")
    summary("Change my password")

    description(
      "Sets a new password for the signed-in user, who must send the current one. Every token issued before (the one of this request included) is revoked and the user's WebSocket connections are closed; the response carries a new session. The attributes may also be wrapped under \"user\". Shares the rate limit of login."
    )

    tag("Auth")
    consumes("application/json")
    produces("application/json")
    bearer_auth()

    parameters do
      body(:body, Schema.ref(:PasswordChange), "Current and new password", required: true)
    end

    response(200, "Password changed, new session", Schema.ref(:AuthResponse))
    body_errors()
    validation_response("Wrong current password, or invalid new one")
    rate_limited()
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
    RephiWeb.Swagger.definitions(%{
      UserRegistration: %{
        type: :object,
        title: "User Registration",
        description: "A new account",
        properties: %{
          email: %{
            type: :string,
            format: :email,
            maxLength: 160,
            description: "Stored trimmed and lowercased; unique regardless of case"
          },
          password: %{
            type: :string,
            minLength: 8,
            description: "8 characters minimum, 72 bytes maximum"
          },
          password_confirmation: %{type: :string, description: "Optional; must match password"}
        },
        required: [:email, :password],
        example: %{email: "user@example.com", password: "a-long-passphrase"}
      },
      LoginCredentials: %{
        type: :object,
        title: "Login Credentials",
        description: "Email (any case) and password",
        properties: %{
          email: %{type: :string, format: :email},
          password: %{type: :string}
        },
        required: [:email, :password],
        example: %{email: "user@example.com", password: "a-long-passphrase"}
      },
      PasswordChange: %{
        type: :object,
        title: "Password Change",
        description: "The current password and the new one",
        properties: %{
          current_password: %{type: :string},
          password: %{
            type: :string,
            minLength: 8,
            description: "8 characters minimum, 72 bytes maximum"
          },
          password_confirmation: %{type: :string, description: "Optional; must match password"}
        },
        required: [:current_password, :password],
        example: %{current_password: "a-long-passphrase", password: "another-passphrase"}
      },
      SessionUser: %{
        type: :object,
        title: "Session User",
        description:
          "The signed-in user: the roles assigned to it (not the inherited ones) and its effective permissions (direct, through roles and inherited), by slug",
        properties: %{
          id: %{type: :integer},
          email: %{type: :string},
          roles: %{type: :array, items: Schema.ref(:Grant)},
          permissions: %{type: :array, items: Schema.ref(:Grant)}
        },
        required: [:id, :email, :roles, :permissions],
        example: %{
          id: 2,
          email: "user@example.com",
          roles: [%{id: 3, name: "User", slug: "user"}],
          permissions: []
        }
      },
      AuthResponse: %{
        type: :object,
        title: "Session Response",
        description: "A new session: the user and the access token to send as a Bearer token",
        properties: %{
          data: %{
            type: :object,
            properties: %{
              user: Schema.ref(:SessionUser),
              token: %{type: :string, description: "JWT access token (24 hours by default)"}
            },
            required: [:user, :token]
          }
        },
        required: [:data],
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
      }
    })
  end
end
