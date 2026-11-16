defmodule RephiWeb.CORS do
  @moduledoc """
  Decides which browser origins may call the API (CORS).

  The allowed origins are plain configuration, read on every request, so a
  release picks them up from the environment without being rebuilt:

      # config/dev.exs
      config :rephi, :cors_origins, ["http://localhost:3000"]

      # production: comma separated, read by config/runtime.exs
      CORS_ORIGINS=https://app.example.com,https://*.example.pages.dev

  An entry is one of:

    * an exact origin - scheme, host and, if it is not the default one, port:
      `https://app.example.com`, `http://localhost:5173`. No path and no
      trailing slash, exactly what the browser sends in the `Origin` header.
    * a wildcard for subdomains - `https://*.example.pages.dev` matches
      `https://abc123.example.pages.dev` and `https://a.b.example.pages.dev`,
      but not `https://example.pages.dev` nor another scheme or port. This is
      meant for preview deployments, whose host name changes on every build.
      The `*` must be the whole first label of the host.

  A bare `*` is rejected: responses allow credentials
  (`Access-Control-Allow-Credentials: true`), and browsers refuse that
  combined with a wildcard origin - besides it being a bad idea.

  Origins that do not match get no CORS headers, so the browser blocks the
  response. Requests without an `Origin` header (curl, server to server) are
  not affected: CORS is a browser mechanism, not access control.

  `validate!/1` runs when the application starts, so a typo in `CORS_ORIGINS`
  stops the boot with a clear message instead of silently blocking a frontend.

  In production the same list is also added to the WebSocket origin check
  (see `config/runtime.exs`).
  """

  @doc """
  The configured origins.
  """
  @spec origins() :: [String.t()]
  def origins, do: Application.get_env(:rephi, :cors_origins, [])

  @doc """
  `:origin` callback for `CORSPlug`: the origin of the request if it is
  allowed, nothing otherwise.
  """
  @spec origin(Plug.Conn.t()) :: [String.t()]
  def origin(%Plug.Conn{} = conn) do
    case Plug.Conn.get_req_header(conn, "origin") do
      [origin | _] -> if allowed?(origin), do: [origin], else: []
      [] -> []
    end
  end

  @doc """
  Whether `origin` matches one of `patterns` (the configured origins by
  default).

  ## Examples

      iex> RephiWeb.CORS.allowed?("https://pr-7.example.pages.dev", ["https://*.example.pages.dev"])
      true

      iex> RephiWeb.CORS.allowed?("https://example.pages.dev.evil.test", ["https://*.example.pages.dev"])
      false

  """
  @spec allowed?(String.t(), [String.t()]) :: boolean()
  def allowed?(origin, patterns \\ origins()) when is_binary(origin) and is_list(patterns) do
    origin = String.downcase(origin)
    Enum.any?(patterns, &matches?(origin, String.downcase(&1)))
  end

  defp matches?(origin, pattern) do
    case String.split(pattern, "://*.", parts: 2) do
      [scheme, domain] ->
        prefix = scheme <> "://"
        suffix = "." <> domain

        String.starts_with?(origin, prefix) and String.ends_with?(origin, suffix) and
          origin
          |> binary_part(byte_size(prefix), byte_size(origin) - byte_size(prefix))
          |> String.replace_suffix(suffix, "")
          |> subdomain?()

      [exact] ->
        origin == exact
    end
  end

  # One or more DNS labels and nothing else: no "/", ":", "@" or empty label
  # that could smuggle a different host in front of the allowed suffix.
  defp subdomain?(labels) do
    labels =~ ~r/\A[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*\z/
  end

  @doc """
  Raises `ArgumentError` unless every entry is a well-formed origin or
  wildcard. Returns the list otherwise.
  """
  @spec validate!([String.t()]) :: [String.t()]
  def validate!(origins) when is_list(origins) do
    Enum.each(origins, fn origin ->
      unless is_binary(origin) and valid?(origin) do
        raise ArgumentError, """
        invalid CORS origin #{inspect(origin)} (CORS_ORIGINS / config :rephi, :cors_origins).

        Expected an exact origin such as "https://app.example.com" or \
        "http://localhost:5173" (scheme, host and optional port; no path, no \
        trailing slash), or a subdomain wildcard such as \
        "https://*.example.pages.dev". A bare "*" is not accepted because the \
        API allows credentials.
        """
      end
    end)

    origins
  end

  defp valid?(origin) do
    origin =~
      ~r/\Ahttps?:\/\/(\*\.)?[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*(:\d{1,5})?\z/i
  end
end
