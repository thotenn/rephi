defmodule RephiWeb.Auth.Pipeline do
  @moduledoc """
  Authenticates an API request from its `Authorization: Bearer <token>` header.

  A request gets past this pipeline only with a valid access token whose user
  still exists and has not revoked it (see `RephiWeb.Auth.Guardian` for what
  "valid" means). That user is then available as `conn.assigns.current_user`,
  and everything it may do as `conn.assigns.current_access`
  (`Rephi.Authorization.Access`, one query). Authorization checks later in
  the request (`RephiWeb.Auth.AuthorizationPlug`,
  `RephiWeb.Auth.AuthorizationHelpers`) read that instead of the database,
  so an authenticated request costs two queries before the action: the user
  and its access.

  Everything else is answered by `RephiWeb.Auth.ErrorHandler` with a `401`:
  no header, a malformed or expired token, a token that is not an access
  token, a token of a deleted user, a token issued before a logout or a
  password change.
  """
  use Guardian.Plug.Pipeline,
    otp_app: :rephi,
    error_handler: RephiWeb.Auth.ErrorHandler,
    module: RephiWeb.Auth.Guardian

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer", claims: %{"typ" => "access"}
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
  plug :assign_current_user
  plug :assign_current_access

  @doc false
  def assign_current_user(conn, _opts) do
    Plug.Conn.assign(conn, :current_user, Guardian.Plug.current_resource(conn))
  end

  @doc false
  def assign_current_access(conn, _opts) do
    Plug.Conn.assign(
      conn,
      :current_access,
      Rephi.Authorization.load_access(conn.assigns.current_user)
    )
  end
end
