defmodule RephiWeb.Auth.Pipeline do
  @moduledoc """
  Authenticates an API request from its `Authorization: Bearer <token>` header.

  A request gets past this pipeline only with a valid access token whose user
  still exists and has not revoked it (see `RephiWeb.Auth.Guardian` for what
  "valid" means). That user is then available as `conn.assigns.current_user`.

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

  @doc false
  def assign_current_user(conn, _opts) do
    Plug.Conn.assign(conn, :current_user, Guardian.Plug.current_resource(conn))
  end
end
