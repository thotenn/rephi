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
  use OpenApiSpex.ControllerSpecs

  import RephiWeb.ApiSpec.Operations

  alias Rephi.Accounts
  alias Rephi.Authorization
  alias RephiWeb.Auth.Guardian
  alias RephiWeb.Schemas

  action_fallback RephiWeb.FallbackController

  tags ["Auth"]

  plug RephiWeb.Plugs.RateLimit, [bucket: :register] when action == :register
  # Checking the current password is as good a password oracle as login.
  plug RephiWeb.Plugs.RateLimit, [bucket: :login] when action in [:login, :change_password]

  operation :register,
    summary: "Register a new user",
    description:
      "Creates an account with the default role (user) and returns a session. The attributes may also be wrapped under \"user\". Rate limited per client IP.",
    request_body: body("Email and password", Schemas.UserRegistration),
    responses:
      responses([
        :body_errors,
        :too_many_requests,
        created: {"Account created, new session", Schemas.AuthResponse},
        unprocessable_entity: "Invalid or taken email, or invalid password"
      ])

  def register(conn, _params) do
    with {:ok, user} <- Accounts.register_user(resource_params(conn, "user")) do
      conn
      |> put_status(:created)
      |> render_session(user)
    end
  end

  operation :login,
    summary: "Log in",
    description:
      "Exchanges credentials for a session. The attributes may also be wrapped under \"user\". Rate limited per client IP.",
    request_body: body("Email and password", Schemas.LoginCredentials),
    responses:
      responses([
        :body_errors,
        :too_many_requests,
        ok: {"Logged in, new session", Schemas.AuthResponse},
        bad_request: "Malformed JSON body, or email or password missing or not a string",
        unauthorized: "Invalid email or password"
      ])

  def login(conn, _params) do
    with {:ok, email, password} <- credentials(resource_params(conn, "user")),
         {:ok, user} <- authenticate(email, password) do
      render_session(conn, user)
    end
  end

  operation :logout,
    summary: "Log out",
    description:
      "Revokes every token issued to the signed-in user (on all devices) and closes its WebSocket connections. No body.",
    security: bearer_auth(),
    responses: responses([:unauthorized, no_content: "Logged out"])

  def logout(conn, _params) do
    with {:ok, _user} <- Accounts.revoke_tokens(conn.assigns.current_user) do
      send_resp(conn, :no_content, "")
    end
  end

  operation :me,
    summary: "Get the signed-in user",
    description: "The signed-in user with the roles assigned to it and its effective permissions",
    security: bearer_auth(),
    responses: responses([:unauthorized, ok: {"The signed-in user", Schemas.MeResponse}])

  def me(conn, _params) do
    render(conn, :me, user: conn.assigns.current_user, access: current_access(conn))
  end

  operation :change_password,
    summary: "Change my password",
    description:
      "Sets a new password for the signed-in user, who must send the current one. Every token issued before (the one of this request included) is revoked and the user's WebSocket connections are closed; the response carries a new session. The attributes may also be wrapped under \"user\". Shares the rate limit of login.",
    security: bearer_auth(),
    request_body: body("Current and new password", Schemas.PasswordChange),
    responses:
      responses([
        :unauthorized,
        :body_errors,
        :too_many_requests,
        ok: {"Password changed, new session", Schemas.AuthResponse},
        unprocessable_entity: "Wrong current password, or invalid new one"
      ])

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
end
