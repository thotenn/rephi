defmodule RephiWeb.Auth.PasswordChangeGate do
  @moduledoc """
  Stops an account whose password an administrator reset
  (`Rephi.Accounts.reset_password/1`) until it sets a new one.

  Runs after `RephiWeb.Auth.Pipeline` (it reads `current_user`, already
  loaded: no query). While `must_change_password` is set, the request
  answers `403` (`:password_change_required`). The router leaves out of it
  the three routes such a user needs: `GET /api/me`, `PUT /api/me/password`
  and `POST /api/users/logout`.

  The temporary password is meant to be used once, to choose a new one: this
  is what keeps it from becoming the account's password.
  """

  alias RephiWeb.FallbackController

  @doc false
  def init(opts), do: opts

  @doc false
  def call(%Plug.Conn{assigns: %{current_user: %{must_change_password: true}}} = conn, _opts) do
    conn
    |> FallbackController.call({:error, :password_change_required})
    |> Plug.Conn.halt()
  end

  def call(conn, _opts), do: conn
end
