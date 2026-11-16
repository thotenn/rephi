defmodule RephiWeb.Auth.Pipeline do
  @moduledoc """
  Authenticates an API request from its `Authorization: Bearer <token>` header,
  assigning `current_user` and `current_access`; anything else is a `401`.
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
