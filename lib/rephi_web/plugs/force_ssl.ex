defmodule RephiWeb.Plugs.ForceSSL do
  @moduledoc """
  Redirects plain HTTP to HTTPS and sends HSTS with the `Plug.SSL` options in
  `config :rephi, :force_ssl` (or `false`), read per request because Phoenix's
  `:force_ssl` endpoint option is fixed at compile time.

  Keep `rewrite_on: [:x_forwarded_proto]` only behind a TLS-terminating proxy: a
  client connecting directly could send the header and skip the redirect.
  """
  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case Application.get_env(:rephi, :force_ssl, false) do
      options when is_list(options) -> Plug.SSL.call(conn, ssl_options(options))
      _disabled -> conn
    end
  end

  # Plug.SSL.init/1 is not free: cache its result per configuration value.
  defp ssl_options(options) do
    key = {__MODULE__, options}

    case :persistent_term.get(key, nil) do
      nil ->
        initialized = Plug.SSL.init(options)
        :persistent_term.put(key, initialized)
        initialized

      initialized ->
        initialized
    end
  end
end
