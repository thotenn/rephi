defmodule RephiWeb.Plugs.BodyParser do
  @moduledoc """
  `Plug.Parsers` that answers a body it cannot accept itself, in the API error
  envelope, instead of raising.

  `Plug.Parsers` raises on malformed JSON (400), a body over the size limit
  (413) or an unsupported content type (415). Phoenix then renders the error
  from the connection as it was when the request *entered* the endpoint,
  which loses the headers earlier plugs had set - notably CORS: the browser
  reports a CORS failure and the frontend never sees the real status.

  Here the error is answered from the current connection, so it keeps those
  headers. It takes the same options as `Plug.Parsers`.
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
