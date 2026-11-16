defmodule RephiWeb.Auth.PasswordChangeGate do
  @moduledoc """
  `403` for a user with `must_change_password` (an admin reset its password).
  Runs after `RephiWeb.Auth.Pipeline`; the router keeps `/me`, `/me/password`
  and logout out of it.
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
