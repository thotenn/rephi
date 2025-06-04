defmodule RephiWeb.Auth.Pipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :rephi,
    error_handler: RephiWeb.Auth.ErrorHandler,
    module: RephiWeb.Auth.Guardian

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
  plug Guardian.Plug.LoadResource, allow_blank: true
  plug :assign_current_user

  # Custom plug to ensure current_user is in assigns
  def assign_current_user(conn, _opts) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        conn
      user ->
        Plug.Conn.assign(conn, :current_user, user)
    end
  end
end
