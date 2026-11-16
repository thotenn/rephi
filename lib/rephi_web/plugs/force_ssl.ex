defmodule RephiWeb.Plugs.ForceSSL do
  @moduledoc """
  Redirects plain HTTP to HTTPS and sends HSTS, when enabled at runtime.

  Phoenix has a `:force_ssl` endpoint option, but it is fixed when the
  endpoint is compiled, so a release cannot switch it. This plug reads its
  options on every request instead:

      config :rephi, :force_ssl,
        rewrite_on: [:x_forwarded_proto],
        hsts: true,
        exclude: [
          hosts: ["localhost", "127.0.0.1"],
          paths: ["/api/health", "/api/health/ready"]
        ]

  The value is `false` (the default: do nothing) or the options of
  `Plug.SSL`, which does the actual work. `config/runtime.exs` turns it on in
  production unless `FORCE_SSL=false`.

  With `rewrite_on: [:x_forwarded_proto]` the scheme is taken from the
  `X-Forwarded-Proto` header, which is what makes this usable behind a proxy
  that terminates TLS. Only keep it if such a proxy is really in front of the
  application: a client connecting directly could send the header itself and
  skip the redirect.

  Health checks are excluded because orchestrators probe them over plain
  HTTP from inside the network.
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

  # `Plug.SSL.init/1` validates the options and builds the HSTS header; cache
  # its result per configuration value instead of redoing it on every request.
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
