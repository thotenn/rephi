defmodule RephiWeb.OpenApiControllerTest do
  # Turns the documentation off in one test (application env).
  use RephiWeb.ConnCase, async: false

  describe "GET /api/openapi" do
    test "serves the OpenAPI 3 document of the API as JSON", %{conn: conn} do
      conn = get(conn, ~p"/api/openapi")

      assert %{"openapi" => "3.0.3", "info" => info, "paths" => paths} = json_response(conn, 200)
      assert info["version"] == Mix.Project.config()[:version]
      assert Map.has_key?(paths, "/api/users/login")
      assert Map.has_key?(paths, "/api/openapi")
    end

    test "is JSON behind the strict CSP of the API", %{conn: conn} do
      conn = get(conn, ~p"/api/openapi")

      assert get_resp_header(conn, "content-security-policy") ==
               ["default-src 'none'; frame-ancestors 'none'"]
    end

    test "is the document RephiWeb.ApiSpec builds", %{conn: conn} do
      expected = RephiWeb.ApiSpec.spec() |> Jason.encode!() |> Jason.decode!()

      assert json_response(get(conn, ~p"/api/openapi"), 200) == expected
    end

    test "is a 404 when the documentation is off", %{conn: conn} do
      put_app_env(:swagger_enabled, false)

      assert error_detail(get(conn, ~p"/api/openapi"), 404) == "Not Found"
    end
  end

  describe "GET /api/swagger" do
    test "serves the Swagger UI pointed at the document", %{conn: conn} do
      html = conn |> get(~p"/api/swagger") |> html_response(200)

      assert html =~ ~s(api_spec_url.pathname = "/api/openapi")
      assert html =~ "<title>Rephi API</title>"
    end
  end

  test "the Swagger 2.0 URLs are gone", %{conn: conn} do
    for path <- ["/api/swagger/swagger.json", "/api/swagger/index.html"] do
      assert error_detail(get(conn, path), 404) == "Not Found"
    end
  end
end
