defmodule RephiWeb.ErrorEnvelopeTest do
  @moduledoc """
  Every error of the API, whoever emits it, uses one of two shapes:

      {"errors": {"detail": "<message>"}}       # general errors
      {"errors": {"<field>": ["<message>"]}}    # validation errors
  """
  use RephiWeb.ConnCase

  defp json_post(conn, path, body) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post(path, body)
  end

  # Runs a request that raises and returns the error the endpoint rendered for
  # it (`render_errors` in config/config.exs).
  defp rendered_error(status, fun) do
    {^status, _headers, body} = assert_error_sent(status, fun)
    Jason.decode!(body)
  end

  describe "errors rendered by the endpoint" do
    test "unknown API route", %{conn: conn} do
      for {method, path} <- [get: "/api/nope", get: "/api", post: "/api/users", delete: "/api/me"] do
        conn = dispatch(conn, @endpoint, method, path)

        assert error_detail(conn, 404) == "Not Found", "unexpected response for #{method} #{path}"
      end
    end

    test "unknown page: there is no HTML catch-all any more", %{conn: conn} do
      for path <- ~w(/nope /dashboard /dashboard/x /landing /admin /assets/x.js /api/swagger.json) do
        conn = get(conn, path)

        assert error_detail(conn, 404) == "Not Found", "unexpected response for #{path}"
        assert get_resp_header(conn, "set-cookie") == []
      end
    end

    test "unknown route, even for a client that only accepts HTML", %{conn: conn} do
      conn = conn |> put_req_header("accept", "text/html") |> get("/api/nope")

      assert error_detail(conn, 404) == "Not Found"
      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    end

    test "malformed JSON body", %{conn: conn} do
      body = rendered_error(400, fn -> json_post(conn, "/api/users/login", ~s({"email": )) end)

      assert body == %{"errors" => %{"detail" => "Bad Request"}}
    end

    test "response format the API does not produce", %{conn: conn} do
      body =
        rendered_error(406, fn ->
          conn |> put_req_header("accept", "text/html") |> get("/api/health")
        end)

      assert body == %{"errors" => %{"detail" => "Not Acceptable"}}
    end
  end

  describe "errors emitted by the application" do
    test "Guardian: no token", %{conn: conn} do
      assert conn |> get("/api/me") |> error_detail(401) == "Authentication required"
    end

    test "Guardian: invalid token", %{conn: conn} do
      conn = conn |> put_req_header("authorization", "Bearer nope") |> get("/api/me")

      assert error_detail(conn, 401) == "Invalid or expired token"
    end

    test "login: wrong credentials", %{conn: conn} do
      conn = post(conn, "/api/users/login", %{email: "nobody@example.com", password: "password"})

      assert error_detail(conn, 401) == "Invalid email or password"
    end

    test "login: missing credentials", %{conn: conn} do
      assert conn |> post("/api/users/login", %{}) |> error_detail(400) ==
               "Email and password are required"
    end

    test "AuthorizationPlug: forbidden", %{conn: conn} do
      conn = conn |> authenticate_user() |> get("/api/users")

      assert error_detail(conn, 403) == "Forbidden"
    end

    test "FallbackController: resource not found", %{conn: conn} do
      {_user, token} = create_user_with_token_and(roles: ["admin"])
      conn = conn |> authenticate_conn(token) |> get("/api/users/999999")

      assert error_detail(conn, 404) == "Not Found"
    end

    test "FallbackController: conflict", %{conn: conn} do
      {user, token} = create_user_with_token_and(permissions: ["roles:assign"])
      role = grant_role(user, "editor")

      conn = conn |> authenticate_conn(token) |> post("/api/users/#{user.id}/roles/#{role.id}")

      assert error_detail(conn, 409) == "Role already assigned to user"
    end

    test "FallbackController: validation errors are keyed by field", %{conn: conn} do
      conn = post(conn, "/api/users/register", %{email: "nope", password: "x"})

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.keys(errors) == ["email", "password"]
      assert Enum.all?(errors, fn {_field, messages} -> Enum.all?(messages, &is_binary/1) end)
    end

    test "no response uses the old \"error\" or \"message\" keys", %{conn: conn} do
      responses = [
        get(conn, "/api/me"),
        post(conn, "/api/users/login", %{email: "a@b", password: "nope"}),
        post(conn, "/api/users/login", %{}),
        post(conn, "/api/users/register", %{}),
        post(conn, "/api/notifications/broadcast", %{})
      ]

      for response <- responses do
        body = Jason.decode!(response.resp_body)

        assert Map.keys(body) == ["errors"], "unexpected body: #{inspect(body)}"
      end
    end
  end

  describe "GET /" do
    test "describes the service as JSON", %{conn: conn} do
      conn = get(conn, "/")

      assert json_response(conn, 200) == %{
               "data" => %{"name" => "rephi", "health" => "/api/health"}
             }

      # No session cookie: the API is stateless.
      assert get_resp_header(conn, "set-cookie") == []
    end
  end
end
