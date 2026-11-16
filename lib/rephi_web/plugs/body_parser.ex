defmodule RephiWeb.Plugs.BodyParser do
  @moduledoc """
  `Plug.Parsers` that answers its own 400/413/415 errors in the API envelope
  instead of raising: Phoenix would render them from the conn as it entered the
  endpoint, without the CORS headers.
  """
  @behaviour Plug

  alias RephiWeb.FallbackController

  @impl Plug
  def init(opts), do: Plug.Parsers.init(opts)

  @impl Plug
  def call(conn, opts) do
    Plug.Parsers.call(conn, opts)
  rescue
    error in [
      Plug.Parsers.ParseError,
      Plug.Parsers.RequestTooLargeError,
      Plug.Parsers.UnsupportedMediaTypeError,
      Plug.Parsers.BadEncodingError
    ] ->
      status = error |> Plug.Exception.status() |> Plug.Conn.Status.reason_atom()

      conn
      |> FallbackController.call({:error, status})
      |> Plug.Conn.halt()
  end
end
