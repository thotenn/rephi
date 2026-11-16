defmodule RephiWeb.Plugs.FrontendAppPlug do
  @moduledoc """
  Serves the built frontend applications found in `priv/static/apps`.

  Mount it once; every directory `priv/static/apps/<name>` becomes available
  under `<mount>/<name>` without touching the router again:

      scope "/app" do
        forward "/", RephiWeb.Plugs.FrontendAppPlug
      end

  With `priv/static/apps/example/` on disk, `GET /app/example/...` resolves as
  follows (first match wins):

    1. **The file itself** - `/app/example/assets/index-3f9a.js`.
    2. **A directory index**, for paths without a file extension -
       `/app/example/login/` serves `login/index.html`, and the slash-less
       `/app/example/login` redirects (`301`) to it, so the page has a single
       URL and its relative links resolve. The root of the app works the same
       way: `/app/example` redirects to `/app/example/`. This is what a
       multi-page static site (Astro with `build.format: "directory"`,
       VitePress…) builds.
    3. **Not found**:
         * a path with a file extension (a missing asset) is a real `404`, so a
           stale chunk never receives HTML with a `200`;
         * if the app ships a `404.html` at its root it is a multi-page site:
           that page is served with status `404`;
         * otherwise the app is a single-page application: extension-less
           paths fall back to its `index.html`, so client-side routes such as
           `/app/example/admin/users` survive a reload.

  Whether an app is a multi-page site or a single-page application is detected
  per app, by the presence of that `404.html`; there is nothing to configure.

  Files are read through `Plug.Static`, which gives content types, `ETag`/`304`,
  `Range` and `HEAD` support and rejects path traversal (the one exception is
  the app's own `404.html`, sent from a fixed path because it needs a `404`
  status). On top of that this plug:

    * only answers `GET` and `HEAD` (anything else is a `405`);
    * only serves apps whose directory name is made of lowercase letters,
      digits, `-` and `_`, starts with a letter or a digit and is at most 64
      characters long;
    * never serves dotfiles (`.env`, `.git/config`…);
    * sets `cache-control: public, max-age=31536000, immutable` for the
      fingerprinted bundles (`assets/` for Vite, `_astro/` for Astro) and
      `no-cache` (revalidate with the `ETag`) for everything else, HTML
      included, so a deploy is picked up on the next navigation.

  Errors use the JSON envelope of the API (`RephiWeb.FallbackController`).

  ## Options

    * `:from` - directory that holds one sub-directory per app. Defaults to
      `config :rephi, :frontend_apps_dir`, and then to `priv/static/apps`
      inside the application directory (`Application.app_dir/2`), which is
      correct both under `mix` and in a release started from any directory.
    * `:fingerprinted` - top-level directories of an app whose files are
      content-hashed by the bundler. Defaults to `["assets", "_astro"]`.
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

  # -- Request resolution ----------------------------------------------------

  # Splits the request path into the app and the (decoded) path inside it, and
  # refuses anything that must never reach the filesystem.
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

  # Same rule `Plug.Static` enforces (it raises on these); checked up front so
  # the client gets a plain 400 instead of an exception.
  defp unsafe?(segment) do
    segment in [".", ".."] or String.contains?(segment, ["/", "\\", ":", <<0>>])
  end

  defp hidden?(segment), do: String.starts_with?(segment, ".")

  # -- Serving ---------------------------------------------------------------

  defp serve(conn, %{path: path} = request) do
    case kind(path) do
      :route -> serve_route(conn, request, String.ends_with?(conn.request_path, "/"))
      kind -> static(conn, request, path) || not_found(conn, request, kind)
    end
  end

  # `/app/x/login/` (or `/app/x/`): the index of that directory.
  defp serve_route(conn, %{path: path} = request, true = _trailing_slash?) do
    static(conn, request, path ++ ["index.html"]) || not_found(conn, request, :route)
  end

  # `/app/x/login`: a file without extension, or a directory whose canonical
  # URL ends with a slash.
  defp serve_route(conn, %{path: path} = request, false = _trailing_slash?) do
    static(conn, request, path) ||
      redirect_to_directory(conn, request) ||
      not_found(conn, request, :route)
  end

  # What the path looks like it is asking for:
  #
  #   * `:route` - no file extension: a page of a multi-page site or a
  #     client-side route of a single-page application
  #   * `:page`  - an explicit HTML file
  #   * `:asset` - any other file
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

  # Serves `path` (relative to the app) through `Plug.Static`. Returns the
  # halted conn when the file exists and `nil` otherwise.
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

  # Redirects to the same URL with a trailing slash when the path is a directory
  # that has an index. The filesystem path is built from segments `check_path/1`
  # validated, and is only probed, never sent. The location is rebuilt from the
  # path segments (not from the raw request path), so it always points to this
  # host.
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

  # The app's own `404.html`, sent with a 404 status. The path is built from
  # the validated app name and a constant, never from the request path.
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
