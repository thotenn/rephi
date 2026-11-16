defmodule RephiWeb.Plugs.FrontendAppPlugTest do
  # Uses application env and changes the working directory.
  use RephiWeb.ConnCase, async: false

  import Plug.Test, only: [conn: 2]

  alias RephiWeb.Plugs.FrontendAppPlug

  @moduletag :tmp_dir

  @secret "TOP-SECRET-OUTSIDE-THE-APPS-DIRECTORY"
  @immutable "public, max-age=31536000, immutable"

  setup %{tmp_dir: tmp_dir} do
    root = Path.join(tmp_dir, "apps")

    write(tmp_dir, "secret.txt", @secret)

    write(
      root,
      "spa/index.html",
      "<!doctype html><html><head></head><body>SPA SHELL</body></html>"
    )

    write(root, "spa/favicon.svg", "<svg xmlns=\"http://www.w3.org/2000/svg\"/>")
    write(root, "spa/LICENSE", "MIT")
    write(root, "spa/.env", @secret)
    write(root, "spa/assets/app-3f9a1c2b.js", "console.log('spa')")
    write(root, "spa/assets/logo-77aa01bc.png", <<137, 80, 78, 71, 13, 10, 26, 10>>)

    write(root, "site/index.html", "<html><body>SITE HOME</body></html>")
    write(root, "site/404.html", "<html><body>SITE NOT FOUND PAGE</body></html>")
    write(root, "site/about.html", "<html><body>SITE ABOUT</body></html>")
    write(root, "site/login/index.html", "<html><body>SITE LOGIN</body></html>")
    write(root, "site/docs/guide/index.html", "<html><body>SITE GUIDE</body></html>")
    write(root, "site/_astro/page.x1y2z3a4.css", "body{}")

    write(root, "Not_Valid/index.html", "INVALID NAME")

    put_env(:frontend_apps_dir, root)

    {:ok, root: root}
  end

  defp write(root, path, content) do
    file = Path.join(root, path)
    File.mkdir_p!(Path.dirname(file))
    File.write!(file, content)
  end

  defp put_env(key, value) do
    previous = Application.get_env(:rephi, key)
    Application.put_env(:rephi, key, value)

    on_exit(fn ->
      if previous do
        Application.put_env(:rephi, key, previous)
      else
        Application.delete_env(:rephi, key)
      end
    end)
  end

  defp header(conn, name), do: conn |> get_resp_header(name) |> List.first()

  describe "single-page application" do
    test "serves index.html at the root of the app", %{conn: conn} do
      for path <- ["/app/spa/", "/app/spa/index.html"] do
        conn = get(conn, path)

        assert html_response(conn, 200) =~ "SPA SHELL"
        assert header(conn, "content-type") == "text/html; charset=utf-8"
        assert header(conn, "cache-control") == "no-cache"
        assert header(conn, "etag")
      end
    end

    test "redirects the root of the app to its trailing-slash URL", %{conn: conn} do
      conn = get(conn, "/app/spa")

      assert response(conn, 301) == ""
      assert header(conn, "location") == "/app/spa/"
    end

    test "does not inject a CSRF token or start a session (SEC-17)", %{conn: conn} do
      conn = get(conn, "/app/spa/")

      refute conn.resp_body =~ "csrf"
      assert conn.resp_body == File.read!(Path.join(FrontendAppPlug.root(), "spa/index.html"))
      assert get_resp_header(conn, "set-cookie") == []
    end

    test "sets the secure browser headers", %{conn: conn} do
      conn = get(conn, "/app/spa/")

      assert header(conn, "x-content-type-options") == "nosniff"
    end

    test "falls back to index.html for client-side routes", %{conn: conn} do
      for path <- ["/app/spa/login", "/app/spa/admin/users", "/app/spa/admin/users/42/"] do
        conn = get(conn, path)

        assert html_response(conn, 200) =~ "SPA SHELL"
        assert header(conn, "cache-control") == "no-cache"
      end
    end

    test "serves fingerprinted assets with their content type, cacheable forever", %{conn: conn} do
      conn = get(conn, "/app/spa/assets/app-3f9a1c2b.js")

      assert response(conn, 200) == "console.log('spa')"
      assert header(conn, "content-type") == "text/javascript"
      assert header(conn, "cache-control") == @immutable
      assert header(conn, "etag")

      conn = get(build_conn(), "/app/spa/assets/logo-77aa01bc.png")

      assert response(conn, 200) == <<137, 80, 78, 71, 13, 10, 26, 10>>
      assert header(conn, "content-type") == "image/png"
      assert header(conn, "cache-control") == @immutable
    end

    test "revalidates files that are not fingerprinted", %{conn: conn} do
      conn = get(conn, "/app/spa/favicon.svg")

      assert response(conn, 200) =~ "<svg"
      assert header(conn, "content-type") == "image/svg+xml"
      assert header(conn, "cache-control") == "no-cache"
    end

    test "answers 304 when the client already has the current version", %{conn: conn} do
      etag = conn |> get("/app/spa/assets/app-3f9a1c2b.js") |> header("etag")

      conn =
        build_conn()
        |> put_req_header("if-none-match", etag)
        |> get("/app/spa/assets/app-3f9a1c2b.js")

      assert response(conn, 304) == ""
    end

    test "serves byte ranges", %{conn: conn} do
      conn =
        conn
        |> put_req_header("range", "bytes=0-6")
        |> get("/app/spa/assets/app-3f9a1c2b.js")

      assert response(conn, 206) == "console"
      assert header(conn, "content-range") == "bytes 0-6/18"
    end

    test "serves an existing file without extension", %{conn: conn} do
      assert conn |> get("/app/spa/LICENSE") |> response(200) == "MIT"
    end

    test "a missing asset is a real 404, not index.html with a 200", %{conn: conn} do
      for path <- ["/app/spa/assets/app-00000000.js", "/app/spa/missing.css", "/app/spa/a/b.png"] do
        conn = get(conn, path)

        assert error_detail(conn, 404) == "Not Found", "unexpected response for #{path}"
      end
    end

    test "a missing HTML file is a 404", %{conn: conn} do
      assert conn |> get("/app/spa/missing.html") |> error_detail(404) == "Not Found"
    end

    test "a directory without an index never fails nor lists its content", %{conn: conn} do
      for path <- ["/app/spa/assets", "/app/spa/assets/"] do
        conn = get(conn, path)

        assert html_response(conn, 200) =~ "SPA SHELL"
        refute conn.resp_body =~ "app-3f9a1c2b"
      end
    end

    test "an app without 404.html and without index.html answers a JSON 404", %{
      conn: conn,
      root: root
    } do
      write(root, "empty/assets/x.js", "1")

      for path <- ["/app/empty", "/app/empty/", "/app/empty/some/route"] do
        assert conn |> get(path) |> error_detail(404) == "Not Found"
      end
    end
  end

  describe "multi-page site" do
    test "serves the home page", %{conn: conn} do
      assert conn |> get("/app/site/") |> html_response(200) =~ "SITE HOME"
    end

    test "serves the index of a directory at its trailing-slash URL", %{conn: conn} do
      for {path, content} <- [
            {"/app/site/login/", "SITE LOGIN"},
            {"/app/site/login/index.html", "SITE LOGIN"},
            {"/app/site/docs/guide/", "SITE GUIDE"}
          ] do
        conn = get(conn, path)

        assert html_response(conn, 200) =~ content
        assert header(conn, "content-type") == "text/html; charset=utf-8"
        assert header(conn, "cache-control") == "no-cache"
        assert header(conn, "etag")
      end
    end

    test "redirects the slash-less URL of a directory that has an index", %{conn: conn} do
      for {path, location} <- [
            {"/app/site", "/app/site/"},
            {"/app/site/login", "/app/site/login/"},
            {"/app/site/docs/guide", "/app/site/docs/guide/"},
            {"/app/site/login?next=%2Fhome&x=1", "/app/site/login/?next=%2Fhome&x=1"}
          ] do
        conn = get(conn, path)

        assert response(conn, 301) == "", "unexpected response for #{path}"
        assert header(conn, "location") == location
      end
    end

    test "does not redirect a directory without an index", %{conn: conn} do
      for path <- ["/app/site/docs", "/app/site/docs/", "/app/site/_astro", "/app/site/_astro/"] do
        assert conn |> get(path) |> html_response(404) =~ "SITE NOT FOUND PAGE"
      end
    end

    test "serves explicit HTML files", %{conn: conn} do
      assert conn |> get("/app/site/about.html") |> html_response(200) =~ "SITE ABOUT"
    end

    test "serves the Astro bundle directory as fingerprinted", %{conn: conn} do
      conn = get(conn, "/app/site/_astro/page.x1y2z3a4.css")

      assert response(conn, 200) == "body{}"
      assert header(conn, "content-type") == "text/css"
      assert header(conn, "cache-control") == @immutable
    end

    test "serves its own 404.html, with a 404, instead of the home page", %{conn: conn} do
      paths = [
        "/app/site/nope",
        "/app/site/nope/",
        "/app/site/docs/nope/",
        "/app/site/login/nope",
        "/app/site/x.html"
      ]

      for path <- paths do
        conn = get(conn, path)

        assert html_response(conn, 404) =~ "SITE NOT FOUND PAGE"
        refute conn.resp_body =~ "SITE HOME"
        assert header(conn, "content-type") == "text/html; charset=utf-8"
        assert header(conn, "cache-control") == "no-cache"
      end
    end

    test "the 404 page itself is served with a 200 when asked for by name", %{conn: conn} do
      assert conn |> get("/app/site/404.html") |> html_response(200) =~ "SITE NOT FOUND PAGE"
    end

    test "a missing asset is a JSON 404", %{conn: conn} do
      assert conn |> get("/app/site/_astro/gone.css") |> error_detail(404) == "Not Found"
    end
  end

  describe "apps" do
    test "an app that does not exist is a 404", %{conn: conn} do
      for path <- ["/app", "/app/", "/app/nope", "/app/nope/", "/app/nope/index.html"] do
        assert conn |> get(path) |> error_detail(404) == "Not Found"
      end
    end

    test "an app whose name is not allowed is a 404 even if the directory exists", %{conn: conn} do
      for name <- ["Not_Valid", "not_valid", "SPA", "%73pa", "spa%20", "-spa", "_spa", "."] do
        conn = get(conn, "/app/#{name}/index.html")

        assert conn.status == 404, "unexpected status #{conn.status} for #{name}"
        refute conn.resp_body =~ "INVALID NAME"
        refute conn.resp_body =~ "SPA SHELL"
      end
    end

    test "a new app directory is served without touching the router", %{conn: conn, root: root} do
      assert conn |> get("/app/brand-new_2/") |> error_detail(404) == "Not Found"

      write(root, "brand-new_2/index.html", "<html>BRAND NEW</html>")

      assert conn |> get("/app/brand-new_2/") |> html_response(200) =~ "BRAND NEW"
    end
  end

  describe "path traversal (SEC-01)" do
    @attempts [
      "/app/spa/../../secret.txt",
      "/app/spa/assets/../../../secret.txt",
      "/app/spa/..",
      "/app/spa/./index.html",
      "/app/../secret.txt",
      "/app/spa/../spa/index.html",
      "/app/spa/%2e%2e/%2e%2e/secret.txt",
      "/app/spa/%2E%2E/%2E%2E/secret.txt",
      "/app/spa/..%2f..%2fsecret.txt",
      "/app/spa/%2e%2e%2f%2e%2e%2fsecret.txt",
      "/app/spa/assets%2f..%2f..%2f..%2fsecret.txt",
      "/app/spa/..%5c..%5csecret.txt",
      "/app/spa/assets/..%5c..%5c..%5csecret.txt",
      "/app/%2e%2e/secret.txt",
      "/app/spa/%252e%252e/%252e%252e/secret.txt",
      "/app/spa/%252e%252e%252fsecret.txt",
      "/app/spa/%2fetc%2fpasswd",
      "/app/spa/%2Fetc%2Fpasswd.txt",
      "/app/spa/C:%5cWindows%5cwin.ini",
      "/app/spa/c:/windows/win.ini",
      "/app/spa/index.html%00.js",
      "/app/spa/%00",
      "/app/spa/assets/app-3f9a1c2b.js%00.png",
      "/app/spa/..%00/secret.txt",
      "/app/spa/%zz.js",
      "/app/spa/%.js",
      "/app/spa/assets/%e0%a4%a.js",
      "/app/spa/%ff%fe.png"
    ]

    for attempt <- @attempts do
      test "#{attempt} is rejected", %{conn: conn} do
        conn = get(conn, unquote(attempt))

        assert conn.request_path == unquote(attempt)
        assert conn.status in [400, 404], "unexpected status #{conn.status}"
        assert %{"errors" => %{"detail" => _}} = Jason.decode!(conn.resp_body)
        refute conn.resp_body =~ @secret
        refute conn.resp_body =~ "SPA SHELL"
      end
    end

    test "a repeated slash is not an absolute path", %{conn: conn} do
      conn = get(conn, "/app/site//etc/passwd")

      assert html_response(conn, 404) =~ "SITE NOT FOUND PAGE"
      refute conn.resp_body =~ "root:"

      conn = get(build_conn(), "/app/spa//etc/passwd")

      assert html_response(conn, 200) =~ "SPA SHELL"
      refute conn.resp_body =~ "root:"
    end

    test "dotfiles are never served", %{conn: conn} do
      for path <- [
            "/app/spa/.env",
            "/app/spa/%2eenv",
            "/app/spa/.git/config",
            "/app/spa/.well-known/x"
          ] do
        conn = get(conn, path)

        assert error_detail(conn, 404) == "Not Found", "unexpected response for #{path}"
        refute conn.resp_body =~ @secret
      end
    end
  end

  describe "methods" do
    test "HEAD is answered like GET", %{conn: conn} do
      conn = head(conn, "/app/spa/assets/app-3f9a1c2b.js")

      assert conn.status == 200
      assert header(conn, "content-type") == "text/javascript"
      assert header(conn, "cache-control") == @immutable
    end

    test "anything else is a 405", %{conn: conn} do
      for method <- [:post, :put, :patch, :delete],
          path <- ["/app/spa/", "/app/spa/assets/app-3f9a1c2b.js", "/app/nope"] do
        conn = dispatch(conn, @endpoint, method, path)

        assert error_detail(conn, 405) == "Method Not Allowed"
        assert header(conn, "allow") == "GET, HEAD"
        refute conn.resp_body =~ "SPA SHELL"
      end
    end
  end

  describe "used directly, outside the router" do
    test "accepts the apps directory as the :from option", %{root: root} do
      Application.delete_env(:rephi, :frontend_apps_dir)
      opts = FrontendAppPlug.init(from: root)

      conn = FrontendAppPlug.call(conn(:get, "/spa/admin"), opts)

      assert conn.status == 200
      assert conn.resp_body =~ "SPA SHELL"
      assert conn.halted
      assert conn.path_info == ["spa", "admin"]
    end

    test "answers HEAD without a body", %{root: root} do
      opts = FrontendAppPlug.init(from: root)

      conn = FrontendAppPlug.call(conn(:head, "/spa/assets/app-3f9a1c2b.js"), opts)

      assert conn.status == 200
      assert conn.resp_body == ""
      assert header(conn, "content-type") == "text/javascript"

      conn = FrontendAppPlug.call(conn(:head, "/spa/some/route"), opts)

      assert conn.status == 200
      assert conn.resp_body == ""
      assert header(conn, "content-type") == "text/html; charset=utf-8"

      conn = FrontendAppPlug.call(conn(:head, "/site/login"), opts)

      assert conn.status == 301
      assert header(conn, "location") == "/site/login/"
    end

    test "a redirect is rebuilt from the path segments, so it never leaves the host", %{
      root: root
    } do
      # With the raw path, a leading `//` would give `Location: //app/...`, another host.
      conn = %{
        conn(:get, "/site/login")
        | request_path: "//app/site/login",
          script_name: ["app"]
      }

      conn = FrontendAppPlug.call(conn, FrontendAppPlug.init(from: root))

      assert conn.status == 301
      assert header(conn, "location") == "/app/site/login/"
    end

    test "the list of fingerprinted directories is configurable", %{root: root} do
      opts = FrontendAppPlug.init(from: root, fingerprinted: ["static"])

      conn = FrontendAppPlug.call(conn(:get, "/spa/assets/app-3f9a1c2b.js"), opts)

      assert header(conn, "cache-control") == "no-cache"
    end

    test "rejects other methods", %{root: root} do
      conn = FrontendAppPlug.call(conn(:post, "/spa/"), FrontendAppPlug.init(from: root))

      assert conn.status == 405
      assert conn.halted
    end
  end

  describe "root/1" do
    test "defaults to priv/static/apps inside the application directory (API-01)" do
      Application.delete_env(:rephi, :frontend_apps_dir)

      assert FrontendAppPlug.root() == Application.app_dir(:rephi, "priv/static/apps")
      assert Path.type(FrontendAppPlug.root()) == :absolute
    end

    test "serves the default directory whatever the working directory is", %{conn: conn} do
      Application.delete_env(:rephi, :frontend_apps_dir)

      # Writes outside its tmp dir: the default root is what a release serves.
      root = FrontendAppPlug.root()
      root_existed? = File.dir?(root)
      name = "zz-test-fixture-#{System.unique_integer([:positive])}"
      app_dir = Path.join(root, name)
      File.mkdir_p!(app_dir)
      File.write!(Path.join(app_dir, "index.html"), "<html>FROM APP DIR</html>")

      on_exit(fn ->
        File.rm_rf!(app_dir)
        unless root_existed?, do: File.rmdir(root)
      end)

      File.cd!(System.tmp_dir!(), fn ->
        assert conn |> get("/app/#{name}/some/route") |> html_response(200) =~ "FROM APP DIR"
      end)
    end
  end
end
