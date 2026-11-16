defmodule RephiWeb.Plugs.FrontendAppPlug do
  @moduledoc """
  Serves the built frontend apps in `priv/static/apps/<name>` under the mount
  point (`forward "/", RephiWeb.Plugs.FrontendAppPlug` in an `/app` scope).

  A path is served as the file itself, then as a directory index (redirecting
  to the trailing slash), then as not found: a missing asset is a `404`, an app
  with a root `404.html` serves it, any other app falls back to `index.html`.

  ## Options

    * `:from` - the apps directory (default: `config :rephi, :frontend_apps_dir`,
      then `priv/static/apps` in the application directory)
    * `:fingerprinted` - top-level directories cached as immutable
      (default: `["assets", "_astro"]`)
  """

  @behaviour Plug

  import Plug.Conn

  alias RephiWeb.FallbackController

  @app_name ~r/\A[a-z0-9][a-z0-9_-]{0,63}\z/
  @fingerprinted ~w(assets _astro)
  @immutable "public, max-age=31536000, immutable"
  @revalidate "no-cache"
  @html_extensions ~w(.html .htm)

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{method: method} = conn, opts) when method in ~w(GET HEAD) do
    case resolve(conn.path_info, opts) do
      {:ok, request} -> serve(conn, request)
      {:error, status} -> reject(conn, status)
    end
  end

  def call(conn, _opts) do
    conn
    |> put_resp_header("allow", "GET, HEAD")
    |> reject(:method_not_allowed)
  end

  @doc """
  Directory that holds one sub-directory per frontend app.
  """
  @spec root(keyword()) :: Path.t()
  def root(opts \\ []) do
    opts[:from] ||
      Application.get_env(:rephi, :frontend_apps_dir) ||
      Application.app_dir(:rephi, "priv/static/apps")
  end

  defp resolve([app | segments], opts) do
    root = root(opts)

    # `URI.decode/1` is lenient: a malformed escape is kept as it is.
    path = Enum.map(segments, &URI.decode/1)

    with :ok <- check_app(root, app),
         :ok <- check_path(path) do
      fingerprinted = Keyword.get(opts, :fingerprinted, @fingerprinted)
      {:ok, %{root: root, app: app, path: path, fingerprinted: fingerprinted}}
    end
  end

  defp resolve([], _opts), do: {:error, :not_found}

  defp check_app(root, app) do
    if Regex.match?(@app_name, app) and File.dir?(Path.join(root, app)) do
      :ok
    else
      {:error, :not_found}
    end
  end

  defp check_path(path) do
    cond do
      Enum.any?(path, &unsafe?/1) -> {:error, :bad_request}
      Enum.any?(path, &hidden?/1) -> {:error, :not_found}
      true -> :ok
    end
  end

  # Plug.Static raises on these; checked first to answer a plain 400.
  defp unsafe?(segment) do
    segment in [".", ".."] or String.contains?(segment, ["/", "\\", ":", <<0>>])
  end

  defp hidden?(segment), do: String.starts_with?(segment, ".")

  defp serve(conn, %{path: path} = request) do
    case kind(path) do
      :route -> serve_route(conn, request, String.ends_with?(conn.request_path, "/"))
      kind -> static(conn, request, path) || not_found(conn, request, kind)
    end
  end

  defp serve_route(conn, %{path: path} = request, true = _trailing_slash?) do
    static(conn, request, path ++ ["index.html"]) || not_found(conn, request, :route)
  end

  defp serve_route(conn, %{path: path} = request, false = _trailing_slash?) do
    static(conn, request, path) ||
      redirect_to_directory(conn, request) ||
      not_found(conn, request, :route)
  end

  defp kind([]), do: :route

  defp kind(path) do
    case path |> List.last() |> Path.extname() |> String.downcase() do
      "" -> :route
      extension when extension in @html_extensions -> :page
      _extension -> :asset
    end
  end

  defp not_found(conn, _request, :asset), do: reject(conn, :not_found)

  defp not_found(conn, request, :page) do
    not_found_page(conn, request) || reject(conn, :not_found)
  end

  defp not_found(conn, request, :route) do
    not_found_page(conn, request) ||
      static(conn, request, ["index.html"]) ||
      reject(conn, :not_found)
  end

  defp static(conn, %{root: root, app: app} = request, path) do
    opts =
      Plug.Static.init(
        at: "/",
        from: root,
        gzip: true,
        brotli: true,
        cache_control_for_etags: cache_control(request, path),
        headers: headers(path)
      )

    served = Plug.Static.call(%{conn | path_info: [app | Enum.map(path, &encode/1)]}, opts)

    if served.halted, do: %{served | path_info: conn.path_info}
  end

  # `Plug.Static` percent-decodes every segment, so hand them back encoded.
  defp encode(segment), do: URI.encode(segment, &URI.char_unreserved?/1)

  defp cache_control(%{fingerprinted: fingerprinted}, [directory, _file | _] = path) do
    if directory in fingerprinted and kind(path) == :asset, do: @immutable, else: @revalidate
  end

  defp cache_control(_request, _path), do: @revalidate

  defp headers(path) do
    if kind(path) == :page, do: %{"content-type" => "text/html; charset=utf-8"}, else: %{}
  end

  # The location is rebuilt from the validated segments, never the raw path,
  # so it always points to this host.
  defp redirect_to_directory(conn, %{root: root, app: app, path: path}) do
    if File.regular?(Path.join([root, app | path] ++ ["index.html"])) do
      conn
      |> put_resp_header("location", directory_url(conn))
      |> send_resp(:moved_permanently, "")
      |> halt()
    end
  end

  defp directory_url(%Plug.Conn{script_name: script_name, path_info: path_info} = conn) do
    path = "/" <> Enum.join(script_name ++ path_info, "/") <> "/"

    case conn.query_string do
      "" -> path
      query -> path <> "?" <> query
    end
  end

  # Built from the validated app name and a constant, never the request path.
  defp not_found_page(conn, %{root: root, app: app}) do
    file = Path.join([root, app, "404.html"])

    if File.regular?(file) do
      conn
      |> put_resp_content_type("text/html")
      |> put_resp_header("cache-control", @revalidate)
      |> send_file(404, file)
      |> halt()
    end
  end

  defp reject(conn, status) do
    conn
    |> FallbackController.call({:error, status})
    |> halt()
  end
end
