defmodule RephiWeb.SwaggerContractTest do
  @moduledoc """
  The Swagger document describes the API that actually runs.

  The document is built the way `mix phx.swagger.generate` builds it (the
  `swagger_path` functions of the routed controllers plus their
  `swagger_definitions/0`), then:

    * every controller route of the router has an operation, and the
      document is well formed (unique operation ids, every `$ref` resolves,
      integer path ids, a 401 on every authenticated operation);
    * every response the document declares is produced by a real request -
      the status and the whole body, against the declared schema, both ways:
      a field the endpoint sends and the schema does not list fails, and so
      does a field the schema lists and the endpoint does not send.

  Adding an endpoint or a response means adding the request that produces it
  to `cases/1` (or to the generic ones: 400, 401, 403, 404, 413, 429).
  """
  use RephiWeb.ConnCase, async: false

  alias Rephi.Accounts
  alias Rephi.Authorization
  alias RephiWeb.RateLimiter

  # Documented responses no request here can produce.
  @not_exercised MapSet.new([{"get", "/api/health/ready", 503}])

  @missing_id 999_999_999

  describe "the document" do
    test "documents every controller route of the router" do
      paths = document()["paths"]

      missing =
        for route <- controller_routes(),
            verb = to_string(route.verb),
            path = swagger_path(route.path),
            not Map.has_key?(paths[path] || %{}, verb),
            do: "#{String.upcase(verb)} #{route.path}"

      assert missing == []
    end

    test "is well formed" do
      document = document()
      operations = operations(document)
      ids = Enum.map(operations, fn {_verb, _path, op} -> op["operationId"] end)

      assert ids -- Enum.uniq(ids) == [], "duplicate operationIds"

      for ref <- refs(document) do
        assert Map.has_key?(document["definitions"], ref), "unresolved $ref #{ref}"
      end

      for {verb, path, op} <- operations do
        assert op["tags"] not in [nil, []], "#{verb} #{path} has no tag"

        for %{"in" => "path"} = param <- op["parameters"] || [] do
          assert param["type"] == "integer", "#{verb} #{path}: #{param["name"]} is not an integer"
        end

        if op["security"], do: assert(Map.has_key?(op["responses"], "401"))
      end
    end
  end

  describe "every documented response" do
    setup :seed

    test "is what the endpoint answers", ctx do
      document = document()

      exercised =
        for {verb, path, status, request} <- cases(ctx) ++ generic_cases(ctx, document),
            into: MapSet.new() do
          conn = request.()
          op = get_in(document, ["paths", path, verb])
          where = "#{String.upcase(verb)} #{path}"

          assert op, "#{where} is not documented"

          assert conn.status == status,
                 "#{where}: expected #{status}, got #{conn.status}: #{conn.resp_body}"

          response = op["responses"][to_string(status)]
          assert response, "#{where} does not document #{status}"
          assert_body(conn, response, document["definitions"], where)

          {verb, path, status}
        end

      documented =
        for {verb, path, op} <- operations(document),
            status <- Map.keys(op["responses"]),
            into: MapSet.new(),
            do: {verb, path, String.to_integer(status)}

      assert MapSet.difference(documented, MapSet.union(exercised, @not_exercised)) ==
               MapSet.new()
    end
  end

  # -- the requests -----------------------------------------------------------

  defp seed(_ctx) do
    {:ok, _result} = Rephi.Seeds.run()

    {admin, admin_token} = create_user_with_token_and(roles: ["admin"])
    {_nobody, nobody_token} = create_user_with_token()

    # child inherits `inherited` from parent; nothing is assigned to child.
    parent = create_role()
    child = create_role()
    {:ok, _} = Authorization.assign_parent_role(child, parent)
    inherited = create_permission()
    {:ok, _} = Authorization.assign_permission_to_role(parent, inherited)

    file = Path.join(System.tmp_dir!(), "swagger-contract-#{System.unique_integer()}.json")
    File.write!(file, Jason.encode!(document()))
    previous = Application.get_env(:rephi, :swagger_file)

    on_exit(fn ->
      File.rm(file)
      restore_env(:rephi, :swagger_file, previous)
      RateLimiter.reset()
    end)

    %{
      admin: admin,
      token: admin_token,
      nobody_token: nobody_token,
      parent: parent,
      child: child,
      inherited: inherited,
      swagger_file: file
    }
  end

  defp cases(%{token: token} = ctx) do
    admin_role = Authorization.get_role_by_slug("admin")
    system_permission = Authorization.get_permission_by_slug("users:view")

    [
      {"get", "/", 200, fn -> call(:get, "/") end},
      {"get", "/api/health", 200, fn -> call(:get, "/api/health") end},
      {"get", "/api/health/ready", 200, fn -> call(:get, "/api/health/ready") end},
      {"get", "/api/swagger/swagger.json", 200,
       fn ->
         Application.put_env(:rephi, :swagger_file, ctx.swagger_file)
         call(:get, "/api/swagger/swagger.json")
       end},
      {"get", "/api/swagger/swagger.json", 404,
       fn ->
         Application.put_env(:rephi, :swagger_file, ctx.swagger_file <> ".missing")
         call(:get, "/api/swagger/swagger.json")
       end},

      # Auth
      {"post", "/api/users/register", 201,
       fn -> call(:post, "/api/users/register", nil, new_credentials()) end},
      {"post", "/api/users/register", 422,
       fn -> call(:post, "/api/users/register", nil, %{email: "nope", password: "short"}) end},
      {"post", "/api/users/login", 200,
       fn ->
         credentials = new_credentials()
         {:ok, _} = Accounts.register_user(credentials)
         call(:post, "/api/users/login", nil, credentials)
       end},
      {"post", "/api/users/login", 400,
       fn -> call(:post, "/api/users/login", nil, %{email: "a@example.com"}) end},
      {"post", "/api/users/login", 401,
       fn ->
         call(:post, "/api/users/login", nil, %{email: "a@example.com", password: "wrong-one"})
       end},
      {"post", "/api/users/logout", 204,
       fn -> call(:post, "/api/users/logout", fresh_token()) end},
      {"get", "/api/me", 200, fn -> call(:get, "/api/me", token) end},
      {"put", "/api/me/password", 200,
       fn ->
         credentials = new_credentials()
         {:ok, user} = Accounts.register_user(credentials)
         {:ok, user_token, _} = RephiWeb.Auth.Guardian.encode_and_sign(user)

         call(:put, "/api/me/password", user_token, %{
           current_password: credentials.password,
           password: "another-long-passphrase"
         })
       end},
      {"put", "/api/me/password", 422,
       fn ->
         call(:put, "/api/me/password", fresh_token(), %{
           current_password: "not-the-password",
           password: "another-long-passphrase"
         })
       end},

      # Notifications
      {"post", "/api/notifications/broadcast", 200,
       fn -> call(:post, "/api/notifications/broadcast", token, %{message: "Hello"}) end},
      {"post", "/api/notifications/broadcast", 422,
       fn -> call(:post, "/api/notifications/broadcast", token, %{message: "  "}) end},

      # Roles
      {"get", "/api/roles", 200, fn -> call(:get, "/api/roles", token) end},
      {"get", "/api/roles", 422, fn -> call(:get, "/api/roles?page=abc", token) end},
      {"get", "/api/roles/{id}", 200, fn -> call(:get, "/api/roles/#{ctx.child.id}", token) end},
      {"post", "/api/roles", 201,
       fn -> call(:post, "/api/roles", token, %{name: "Editor", slug: unique("editor")}) end},
      {"post", "/api/roles", 422, fn -> call(:post, "/api/roles", token, %{}) end},
      {"put", "/api/roles/{id}", 200,
       fn -> call(:put, "/api/roles/#{create_role().id}", token, %{name: "Renamed"}) end},
      {"patch", "/api/roles/{id}", 200,
       fn -> call(:patch, "/api/roles/#{create_role().id}", token, %{description: "Text"}) end},
      {"put", "/api/roles/{id}", 422,
       fn -> call(:put, "/api/roles/#{admin_role.id}", token, %{slug: "boss"}) end},
      {"patch", "/api/roles/{id}", 422,
       fn -> call(:patch, "/api/roles/#{admin_role.id}", token, %{name: ""}) end},
      {"delete", "/api/roles/{id}", 204,
       fn -> call(:delete, "/api/roles/#{create_role().id}", token) end},
      {"delete", "/api/roles/{id}", 409,
       fn -> call(:delete, "/api/roles/#{admin_role.id}", token) end},
      {"get", "/api/roles/{id}/permissions", 200,
       fn -> call(:get, "/api/roles/#{ctx.child.id}/permissions", token) end},
      {"post", "/api/users/{user_id}/roles/{role_id}", 201,
       fn ->
         call(:post, "/api/users/#{create_user().id}/roles/#{ctx.child.id}", token, %{
           notes: "Covers for the lead"
         })
       end},
      {"post", "/api/users/{user_id}/roles/{role_id}", 409,
       fn -> call(:post, "/api/users/#{ctx.admin.id}/roles/#{admin_role.id}", token) end},
      {"post", "/api/users/{user_id}/roles/{role_id}", 422,
       fn ->
         call(:post, "/api/users/#{create_user().id}/roles/#{ctx.child.id}", token, %{notes: 1})
       end},
      {"delete", "/api/users/{user_id}/roles/{role_id}", 204,
       fn ->
         user = create_user()
         grant_role(user, ctx.child.slug)
         call(:delete, "/api/users/#{user.id}/roles/#{ctx.child.id}", token)
       end},
      {"delete", "/api/users/{user_id}/roles/{role_id}", 409,
       fn -> call(:delete, "/api/users/#{ctx.admin.id}/roles/#{admin_role.id}", token) end},

      # Permissions
      {"get", "/api/permissions", 200, fn -> call(:get, "/api/permissions", token) end},
      {"get", "/api/permissions", 422,
       fn -> call(:get, "/api/permissions?page_size=0", token) end},
      {"get", "/api/permissions/{id}", 200,
       fn -> call(:get, "/api/permissions/#{system_permission.id}", token) end},
      {"post", "/api/permissions", 201,
       fn ->
         call(:post, "/api/permissions", token, %{
           name: "Export",
           slug: unique("reports:export"),
           parent_id: ctx.inherited.id
         })
       end},
      {"post", "/api/permissions", 422,
       fn -> call(:post, "/api/permissions", token, %{name: "No", slug: "nocolon"}) end},
      {"put", "/api/permissions/{id}", 200,
       fn -> call(:put, "/api/permissions/#{create_permission().id}", token, %{name: "New"}) end},
      {"patch", "/api/permissions/{id}", 200,
       fn ->
         call(:patch, "/api/permissions/#{create_permission().id}", token, %{description: "D"})
       end},
      {"put", "/api/permissions/{id}", 422,
       fn ->
         call(:put, "/api/permissions/#{system_permission.id}", token, %{slug: "users:see"})
       end},
      {"patch", "/api/permissions/{id}", 422,
       fn ->
         permission = create_permission()
         call(:patch, "/api/permissions/#{permission.id}", token, %{parent_id: permission.id})
       end},
      {"delete", "/api/permissions/{id}", 204,
       fn -> call(:delete, "/api/permissions/#{create_permission().id}", token) end},
      {"delete", "/api/permissions/{id}", 409,
       fn -> call(:delete, "/api/permissions/#{system_permission.id}", token) end},
      {"post", "/api/roles/{role_id}/permissions/{permission_id}", 201,
       fn ->
         call(:post, "/api/roles/#{create_role().id}/permissions/#{system_permission.id}", token)
       end},
      {"post", "/api/roles/{role_id}/permissions/{permission_id}", 409,
       fn ->
         call(:post, "/api/roles/#{admin_role.id}/permissions/#{system_permission.id}", token)
       end},
      {"post", "/api/roles/{role_id}/permissions/{permission_id}", 422,
       fn ->
         path = "/api/roles/#{create_role().id}/permissions/#{system_permission.id}"
         call(:post, path, token, %{notes: %{}})
       end},
      {"delete", "/api/roles/{role_id}/permissions/{permission_id}", 204,
       fn ->
         role = create_role()
         {:ok, _} = Authorization.assign_permission_to_role(role, system_permission)
         call(:delete, "/api/roles/#{role.id}/permissions/#{system_permission.id}", token)
       end},
      {"delete", "/api/roles/{role_id}/permissions/{permission_id}", 409,
       fn ->
         call(:delete, "/api/roles/#{ctx.child.id}/permissions/#{ctx.inherited.id}", token)
       end},

      # Users
      {"get", "/api/users", 200, fn -> call(:get, "/api/users", token) end},
      {"get", "/api/users", 422, fn -> call(:get, "/api/users?page=-1", token) end},
      {"get", "/api/users/{id}", 200, fn -> call(:get, "/api/users/#{ctx.admin.id}", token) end},
      {"put", "/api/users/{id}", 200,
       fn -> call(:put, "/api/users/#{create_user().id}", token, %{email: unique_email()}) end},
      {"patch", "/api/users/{id}", 200,
       fn -> call(:patch, "/api/users/#{create_user().id}", token, %{email: unique_email()}) end},
      {"put", "/api/users/{id}", 422,
       fn -> call(:put, "/api/users/#{create_user().id}", token, %{password: "x"}) end},
      {"patch", "/api/users/{id}", 422,
       fn -> call(:patch, "/api/users/#{create_user().id}", token, %{email: "not an email"}) end},
      {"delete", "/api/users/{id}", 204,
       fn -> call(:delete, "/api/users/#{create_user().id}", token) end},
      {"delete", "/api/users/{id}", 409,
       fn -> call(:delete, "/api/users/#{ctx.admin.id}", token) end},
      {"get", "/api/users/{id}/roles", 200,
       fn -> call(:get, "/api/users/#{ctx.admin.id}/roles", token) end}
    ]
  end

  # The responses every operation of a kind answers the same way, derived
  # from what the document declares.
  defp generic_cases(%{token: token, nobody_token: nobody_token}, document) do
    for {verb, path, op} <- operations(document),
        status <- Map.keys(op["responses"]) |> Enum.map(&String.to_integer/1),
        status != 401 or op["security"] != nil,
        request = generic_request(status, verb, path, token, nobody_token),
        request != nil,
        do: {verb, path, status, request}
  end

  defp generic_request(401, verb, path, _token, _nobody) do
    fn -> call(verb, fill(path, 1)) end
  end

  defp generic_request(403, verb, path, _token, nobody_token) do
    fn -> call(verb, fill(path, 1), nobody_token, %{}) end
  end

  defp generic_request(404, verb, path, token, _nobody) do
    if path =~ "{", do: fn -> call(verb, fill(path, @missing_id), token, %{}) end
  end

  defp generic_request(400, verb, path, token, _nobody) do
    fn -> call(verb, fill(path, 1), token, ~s({"broken": )) end
  end

  defp generic_request(413, verb, path, token, _nobody) do
    fn ->
      call(verb, fill(path, 1), token, Jason.encode!(%{pad: String.duplicate("x", 1_000_001)}))
    end
  end

  defp generic_request(429, verb, path, token, _nobody) do
    fn ->
      previous = Application.get_env(:rephi, RephiWeb.Plugs.RateLimit)

      Application.put_env(:rephi, RephiWeb.Plugs.RateLimit,
        enabled: true,
        trusted_proxies: 0,
        login: [limit: 1, window_seconds: 60],
        register: [limit: 1, window_seconds: 60]
      )

      RateLimiter.reset()

      try do
        call(verb, fill(path, 1), token, %{})
        call(verb, fill(path, 1), token, %{})
      after
        Application.put_env(:rephi, RephiWeb.Plugs.RateLimit, previous)
        RateLimiter.reset()
      end
    end
  end

  defp generic_request(_status, _verb, _path, _token, _nobody), do: nil

  defp call(verb, path, token \\ nil, body \\ nil) do
    conn = put_req_header(build_conn(), "accept", "application/json")
    conn = if token, do: authenticate_conn(conn, token), else: conn

    {conn, body} =
      case body do
        nil ->
          {conn, nil}

        body when is_binary(body) ->
          {put_req_header(conn, "content-type", "application/json"), body}

        body ->
          {put_req_header(conn, "content-type", "application/json"), Jason.encode!(body)}
      end

    dispatch(conn, @endpoint, verb, path, body)
  end

  defp fresh_token do
    {_user, token} = create_user_with_token()
    token
  end

  defp new_credentials, do: %{email: unique_email(), password: "a-long-passphrase"}
  defp unique_email, do: "#{unique("someone")}@example.com"
  defp unique(prefix), do: "#{prefix}_#{System.unique_integer([:positive])}"

  defp fill(path, id), do: Regex.replace(~r/\{[a-z_]+\}/, path, to_string(id))

  defp restore_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_env(app, key, value), do: Application.put_env(app, key, value)

  # -- the document -----------------------------------------------------------

  # What `mix phx.swagger.generate` builds, as decoded JSON.
  defp document do
    routes = controller_routes()

    paths =
      for route <- routes,
          fun = :"swagger_path_#{route.plug_opts}",
          function_exported?(route.plug, fun, 1),
          reduce: %{} do
        paths ->
          operation =
            apply(route.plug, fun, [%{verb: route.verb, path: swagger_path(route.path)}])

          Map.merge(paths, operation, fn _path, a, b -> Map.merge(a, b) end)
      end

    definitions =
      for controller <- routes |> Enum.map(& &1.plug) |> Enum.uniq(),
          function_exported?(controller, :swagger_definitions, 0),
          reduce: %{},
          do: (definitions -> Map.merge(definitions, controller.swagger_definitions()))

    %{paths: paths, definitions: definitions} |> Jason.encode!() |> Jason.decode!()
  end

  defp controller_routes do
    for route <- RephiWeb.Router.__routes__(),
        is_atom(route.plug_opts),
        match?(["RephiWeb" | _], Module.split(route.plug)),
        Code.ensure_loaded?(route.plug),
        do: route
  end

  defp swagger_path(path), do: Regex.replace(~r/:([^\/]+)/, path, "{\\1}")

  defp operations(document) do
    for {path, verbs} <- document["paths"], {verb, op} <- verbs, do: {verb, path, op}
  end

  defp refs(%{"$ref" => "#/definitions/" <> name}), do: [name]
  defp refs(map) when is_map(map), do: Enum.flat_map(Map.values(map), &refs/1)
  defp refs(list) when is_list(list), do: Enum.flat_map(list, &refs/1)
  defp refs(_other), do: []

  # -- the response against the schema ----------------------------------------

  defp assert_body(conn, %{"schema" => schema}, definitions, where) do
    assert ["application/json" <> _] = get_resp_header(conn, "content-type")
    assert_schema(Jason.decode!(conn.resp_body), schema, definitions, where)
  end

  defp assert_body(conn, _response, _definitions, where) do
    assert conn.resp_body == "", "#{where}: documented without a body, got #{conn.resp_body}"
  end

  defp assert_schema(value, %{"$ref" => "#/definitions/" <> name}, definitions, where) do
    assert_schema(value, Map.fetch!(definitions, name), definitions, "#{where} (#{name})")
  end

  defp assert_schema(nil, %{"x-nullable" => true}, _definitions, _where), do: :ok

  defp assert_schema(value, %{"type" => "object"} = schema, definitions, where) do
    assert is_map(value), "#{where}: expected an object, got #{inspect(value)}"

    case schema do
      %{"properties" => properties} ->
        keys = Map.keys(value)
        listed = Map.keys(properties)

        assert keys -- listed == [], "#{where}: undocumented fields #{inspect(keys -- listed)}"
        assert listed -- keys == [], "#{where}: phantom fields #{inspect(listed -- keys)}"

        for {key, property} <- properties,
            do: assert_schema(value[key], property, definitions, "#{where}.#{key}")

      %{"additionalProperties" => property} ->
        for {key, item} <- value,
            do: assert_schema(item, property, definitions, "#{where}.#{key}")

      _free_form ->
        :ok
    end
  end

  defp assert_schema(value, %{"type" => "array", "items" => items}, definitions, where) do
    assert is_list(value), "#{where}: expected an array, got #{inspect(value)}"
    for item <- value, do: assert_schema(item, items, definitions, "#{where}[]")
  end

  defp assert_schema(value, %{"type" => type} = schema, _definitions, where) do
    assert scalar?(type, value), "#{where}: expected #{type}, got #{inspect(value)}"

    if schema["format"] == "date-time" do
      assert {:ok, _datetime, 0} = DateTime.from_iso8601(value), "#{where}: not a UTC date-time"
    end

    if enum = schema["enum"], do: assert(value in enum, "#{where}: #{inspect(value)} not in enum")
  end

  defp scalar?("integer", value), do: is_integer(value)
  defp scalar?("string", value), do: is_binary(value)
  defp scalar?("boolean", value), do: is_boolean(value)
  defp scalar?(_type, _value), do: false
end
