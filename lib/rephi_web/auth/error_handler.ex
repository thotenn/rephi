defmodule RephiWeb.Auth.ErrorHandler do
  @moduledoc """
  Answers requests rejected by the Guardian pipeline with a `401` in the API error
  envelope.
  """

  @behaviour Guardian.Plug.ErrorHandler

  alias RephiWeb.FallbackController

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {type, _reason}, _opts) do
    conn
    |> FallbackController.call({:error, :unauthorized, message(type)})
    |> Plug.Conn.halt()
  end

  defp message(:unauthenticated), do: "Authentication required"
  defp message(_type), do: "Invalid or expired token"
end
