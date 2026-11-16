defmodule RephiWeb.CORS do
  @moduledoc """
  Decides which browser origins may call the API (CORS), from
  `config :rephi, :cors_origins` (`CORS_ORIGINS` in production), read per request.

  An entry is an exact origin (`https://app.example.com`) or a subdomain wildcard
  (`https://*.example.pages.dev`, the `*` being the whole first label). A bare `*`
  is rejected: responses allow credentials.
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

  # DNS labels only: no "/", ":", "@" or empty label that could smuggle in another host.
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
