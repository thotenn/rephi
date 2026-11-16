defmodule RephiWeb.SwaggerControllerTest do
  # Changes application env, so it cannot run concurrently with other tests.
  use RephiWeb.ConnCase, async: false

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    previous = Application.get_env(:rephi, :swagger_file)
    file = Path.join(tmp_dir, "swagger.json")
    Application.put_env(:rephi, :swagger_file, file)

    on_exit(fn ->
      if previous do
        Application.put_env(:rephi, :swagger_file, previous)
      else
        Application.delete_env(:rephi, :swagger_file)
      end
    end)

    {:ok, swagger_file: file}
  end

  describe "GET /api/swagger/swagger.json" do
    test "serves the generated document as JSON", %{conn: conn, swagger_file: file} do
      File.write!(file, ~s({"swagger":"2.0","paths":{"/api/health":{}}}))

      conn = get(conn, "/api/swagger/swagger.json")

      assert %{"swagger" => "2.0", "paths" => %{"/api/health" => _}} = json_response(conn, 200)
      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    end

    test "answers a 404 with a hint while it has not been generated", %{
      conn: conn,
      swagger_file: file
    } do
      refute File.exists?(file)

      conn = get(conn, "/api/swagger/swagger.json")

      assert error_detail(conn, 404) =~ "mix phx.swagger.generate"
    end

    test "is not shadowed by the Swagger UI forward", %{conn: conn} do
      assert %{plug: RephiWeb.SwaggerController, plug_opts: :show} =
               Phoenix.Router.route_info(
                 RephiWeb.Router,
                 "GET",
                 "/api/swagger/swagger.json",
                 conn.host
               )
    end
  end

  test "defaults to priv/static/swagger.json inside the application directory" do
    Application.delete_env(:rephi, :swagger_file)

    assert RephiWeb.SwaggerController.file() ==
             Application.app_dir(:rephi, "priv/static/swagger.json")

    assert Path.type(RephiWeb.SwaggerController.file()) == :absolute
  end

  test "the Swagger UI is still served", %{conn: conn} do
    conn = get(conn, "/api/swagger/index.html")

    assert html_response(conn, 200) =~ ~s(url: "swagger.json")
  end

  describe "swagger_path blocks" do
    # The same thing `mix phx.swagger.generate` does for every route.
    defp documented_routes do
      for %{plug: controller, plug_opts: action, path: path, verb: verb} = route <-
            RephiWeb.Router.__routes__(),
          is_atom(action),
          function = :"swagger_path_#{action}",
          Code.ensure_loaded?(controller) and function_exported?(controller, function, 1) do
        {verb, path, apply(controller, function, [route])}
      end
    end

    test "evaluate for every documented route" do
      routes = documented_routes()

      assert length(routes) > 20

      for {_verb, _path, swagger} <- routes do
        assert %{} = swagger
        assert map_size(swagger) == 1
      end
    end

    test "document the health checks" do
      paths = for {:get, path, _swagger} <- documented_routes(), do: path

      assert "/api/health" in paths
      assert "/api/health/ready" in paths
    end
  end

  test "the generator is not configured with an endpoint, so no host is baked in" do
    for {_file, opts} <- Application.fetch_env!(:rephi, :phoenix_swagger)[:swagger_files] do
      assert opts[:router] == RephiWeb.Router
      refute Keyword.has_key?(opts, :endpoint)
    end
  end
end
