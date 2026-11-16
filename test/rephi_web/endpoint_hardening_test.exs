defmodule RephiWeb.EndpointHardeningTest do
  @moduledoc """
  CORS (SEC-14, API-17), HTTPS redirect (SEC-15), secure headers on the API
  (SEC-15), the Swagger switch (SEC-20) and the "every API route needs a
  token" invariant.
  """
  use RephiWeb.ConnCase, async: false

  alias RephiWeb.CORS

  # config/test.exs: ["http://localhost:3000", "https://*.preview.example.com"]

  defp preflight(origin) do
    build_conn()
    |> put_req_header("origin", origin)
    |> put_req_header("access-control-request-method", "POST")
    |> put_req_header("access-control-request-headers", "authorization,content-type")
    |> options("/api/users/login")
  end

  describe "CORS" do
    test "a preflight from an allowed origin gets the CORS headers" do
      conn = preflight("http://localhost:3000")

      assert conn.status == 204
      assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:3000"]
      assert get_resp_header(conn, "access-control-allow-credentials") == ["true"]
      assert [methods] = get_resp_header(conn, "access-control-allow-methods")
      assert methods =~ "POST"
    end

    test "a preflight from another origin gets none" do
      for origin <- [
            "http://localhost:3001",
            "https://evil.example",
            "http://localhost:3000.evil.example",
            "null"
          ] do
        conn = preflight(origin)
        assert get_resp_header(conn, "access-control-allow-origin") == [], origin
        assert get_resp_header(conn, "access-control-allow-credentials") == [], origin
      end
    end

    test "the wildcard form accepts subdomains of the pattern only" do
      assert get_resp_header(
               preflight("https://pr-42.preview.example.com"),
               "access-control-allow-origin"
             ) ==
               ["https://pr-42.preview.example.com"]

      for origin <- [
            "https://preview.example.com",
            "http://pr-42.preview.example.com",
            "https://pr-42.preview.example.com:8443",
            "https://evil.example/.preview.example.com",
            "https://evil.example?.preview.example.com",
            "https://evil.example#.preview.example.com",
            "https://user@evil.example.preview.example.com.attacker.test"
          ] do
        assert get_resp_header(preflight(origin), "access-control-allow-origin") == [], origin
      end
    end

    test "the origins are read at runtime" do
      put_app_env(:cors_origins, ["https://app.example.com"])

      assert get_resp_header(preflight("https://app.example.com"), "access-control-allow-origin") ==
               ["https://app.example.com"]

      assert get_resp_header(preflight("http://localhost:3000"), "access-control-allow-origin") ==
               []
    end

    test "errors produced by the body parser carry the headers too" do
      conn =
        build_conn()
        |> put_req_header("origin", "http://localhost:3000")
        |> put_req_header("content-type", "application/json")

      malformed = post(conn, "/api/users/login", "{bad")
      assert error_detail(malformed, 400) == "Bad Request"

      assert get_resp_header(malformed, "access-control-allow-origin") == [
               "http://localhost:3000"
             ]

      too_large =
        post(conn, "/api/users/login", ~s({"a":") <> String.duplicate("x", 1_000_001) <> ~s("}))

      assert error_detail(too_large, 413) == "Request Entity Too Large"

      assert get_resp_header(too_large, "access-control-allow-origin") == [
               "http://localhost:3000"
             ]

      unsupported =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/users/login", "x")

      assert unsupported.status in [400, 415]

      assert get_resp_header(unsupported, "access-control-allow-origin") == [
               "http://localhost:3000"
             ]
    end

    test "validate!/1 accepts exact origins and subdomain wildcards" do
      origins = [
        "https://app.example.com",
        "http://localhost:5173",
        "https://*.example.pages.dev",
        "http://127.0.0.1:4000"
      ]

      assert CORS.validate!(origins) == origins
    end

    test "validate!/1 rejects *, paths, trailing slashes and partial wildcards" do
      for origin <- [
            "*",
            "https://*",
            "app.example.com",
            "https://app.example.com/",
            "https://app.example.com/path",
            "https://*example.com",
            "https://app.*.example.com",
            "ftp://example.com",
            ""
          ] do
        assert_raise ArgumentError, ~r/invalid CORS origin/, fn -> CORS.validate!([origin]) end
      end
    end
  end

  describe "HTTPS (RephiWeb.Plugs.ForceSSL)" do
    setup do
      put_app_env(:force_ssl,
        rewrite_on: [:x_forwarded_proto],
        hsts: true,
        exclude: [hosts: ["localhost", "127.0.0.1"], paths: ["/api/health", "/api/health/ready"]]
      )
    end

    defp request(path, headers) do
      conn = %{build_conn() | host: "api.example.com"}
      headers |> Enum.reduce(conn, fn {k, v}, c -> put_req_header(c, k, v) end) |> get(path)
    end

    test "plain HTTP is redirected to HTTPS" do
      conn = request("/api/me", [])
      assert conn.status == 301
      assert get_resp_header(conn, "location") == ["https://api.example.com/api/me"]
    end

    test "HTTPS behind a proxy (X-Forwarded-Proto) passes and gets HSTS" do
      conn = request("/api/me", [{"x-forwarded-proto", "https"}])
      assert conn.status == 401
      assert [hsts] = get_resp_header(conn, "strict-transport-security")
      assert hsts =~ "max-age="
    end

    test "health checks are never redirected" do
      assert request("/api/health", []).status == 200
    end

    test "off when the configuration is false" do
      put_app_env(:force_ssl, false)
      assert request("/api/me", []).status == 401
    end
  end

  describe "secure headers on the API" do
    test "an authenticated JSON response carries them" do
      {_user, token} = create_user_with_token()
      conn = build_conn() |> authenticate_conn(token) |> get(~p"/api/me")

      assert json_response(conn, 200)
      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]

      assert get_resp_header(conn, "content-security-policy") ==
               ["default-src 'none'; frame-ancestors 'none'"]
    end

    test "so does an error from the authentication pipeline" do
      conn = get(build_conn(), ~p"/api/me")
      assert conn.status == 401
      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    end
  end

  describe "Swagger switch" do
    test "on, the UI is served" do
      assert get(build_conn(), "/api/swagger/index.html").status == 200
    end

    test "off, the UI and the document are a 404" do
      put_app_env(:swagger_enabled, false)

      for path <- ["/api/swagger", "/api/swagger/index.html", "/api/swagger/swagger.json"] do
        assert error_detail(get(build_conn(), path), 404) == "Not Found"
      end
    end
  end

  describe "every API route" do
    @public [
      {"POST", "/api/users/register"},
      {"POST", "/api/users/login"},
      {"GET", "/api/health"},
      {"GET", "/api/health/ready"},
      {"GET", "/api/swagger/swagger.json"}
    ]

    test "but the public ones answers 401 without a token" do
      routes =
        for %{verb: verb, path: "/api/" <> _ = path} <- RephiWeb.Router.__routes__(),
            verb != :*,
            method = verb |> to_string() |> String.upcase(),
            {method, path} not in @public,
            do: {method, path}

      assert length(routes) > 10

      for {method, path} <- routes do
        path = String.replace(path, ~r/:\w+/, "1")
        conn = dispatch(build_conn(), @endpoint, method, path, nil)

        assert conn.status == 401, "#{method} #{path} answered #{conn.status}"
      end
    end
  end
end
