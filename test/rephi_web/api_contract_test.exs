defmodule RephiWeb.ApiContractTest do
  @moduledoc """
  The OpenAPI document matches the running API: every route documented, a valid document,
  and every documented response produced by a real request and checked both ways.
  """
  use RephiWeb.ConnCase, async: false

  alias OpenApiSpex.Cast.Error
  alias OpenApiSpex.Schema
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
            path = open_api_path(route.path),
            not Map.has_key?(paths[path] || %{}, verb),
            do: "#{String.upcase(verb)} #{route.path}"

      assert missing == []
    end

    test "is well formed" do
      document = document()
      operations = operations(document)
      ids = Enum.map(operations, fn {_verb, _path, op} -> op["operationId"] end)
      tags = MapSet.new(document["tags"], & &1["name"])
      schemes = document["components"]["securitySchemes"]

      assert document["openapi"] =~ ~r/^3\.0\.\d+$/
      assert document["info"]["version"] == Mix.Project.config()[:version]
      assert ids -- Enum.uniq(ids) == [], "duplicate operationIds"

      for ref <- refs(document) do
        assert get_in(document, ref_path(ref)), "unresolved $ref #{ref}"
      end

      for {verb, path, op} <- operations do
        where = "#{String.upcase(verb)} #{path}"
        assert op["tags"] not in [nil, []], "#{where} has no tag"
        assert Enum.all?(op["tags"], &(&1 in tags)), "#{where}: undeclared tag"

        path_params = for %{"in" => "path"} = param <- op["parameters"] || [], do: param

        for param <- path_params do
          assert param["schema"]["type"] == "integer",
                 "#{where}: #{param["name"]} is not an integer"
        end

        assert Enum.sort(for(p <- path_params, do: p["name"])) ==
                 Enum.sort(for([_, name] <- Regex.scan(~r/\{(\w+)\}/, path), do: name)),
               "#{where}: path parameters"

        for requirement <- op["security"] || [], name <- Map.keys(requirement) do
          assert Map.has_key?(schemes, name), "#{where}: unknown security scheme #{name}"
        end

        if op["security"], do: assert(Map.has_key?(op["responses"], "401"), where)
      end

      # So that casting catches a declared field the endpoint does not send.
      for {name, schema} <- response_schemas(document),
          {where, object} <- objects(schema, name) do
        properties = Map.keys(object["properties"])

        assert Enum.sort(object["required"] || []) == Enum.sort(properties),
               "#{where}: required must list every property"
      end
    end

    test "documents the password gate on exactly the routes behind it" do
      paths = document()["paths"]

      for route <- controller_routes() do
        op = paths[open_api_path(route.path)][to_string(route.verb)]
        where = "#{String.upcase(to_string(route.verb))} #{route.path}"
        gated? = gated?(route)
        forbidden = get_in(op, ["responses", "403", "description"]) || ""

        assert String.contains?(forbidden, "PUT /api/me/password") == gated?,
               "#{where}: the 403 of the password gate (gated: #{gated?})"
      end
    end

    test "every example matches its schema" do
      spec = RephiWeb.ApiSpec.spec()

      examples =
        for {name, %Schema{example: example}} <- spec.components.schemas,
            example != nil,
            do: {name, example}

      assert length(examples) > 10

      for {name, example} <- examples do
        OpenApiSpex.TestAssertions.assert_schema(example, name, strict(spec))
      end
    end
  end

  describe "every documented response" do
    setup :seed

    test "is what the endpoint answers", ctx do
      document = document()
      spec = strict(RephiWeb.ApiSpec.spec())

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

          for {header, %{"schema" => schema}} <- response["headers"] || %{} do
            values = get_resp_header(conn, header)
            assert values != [], "#{where}: no #{header} header"

            if schema["enum"],
              do: assert(Enum.all?(values, &(&1 in schema["enum"])), "#{where}: #{header}")
          end

          operation = Map.fetch!(spec.paths[path], String.to_existing_atom(verb))
          assert_body(conn, operation.responses[status], response, spec, document, where)

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

    test "is the password gate's 403 for a user whose password was reset" do
      {:ok, user, _password} = Accounts.reset_password(create_user())
      {:ok, token, _claims} = RephiWeb.Auth.Guardian.encode_and_sign(Accounts.get_user(user.id))
      spec = strict(RephiWeb.ApiSpec.spec())
      document = document()

      gated = Enum.filter(controller_routes(), &gated?/1)

      assert length(gated) > 20

      for route <- gated do
        path = open_api_path(route.path)
        conn = call(route.verb, fill(path, 1), token, %{})
        where = "#{String.upcase(to_string(route.verb))} #{route.path}"

        assert %{"errors" => %{"detail" => "Your password was reset" <> _}} =
                 json_response(conn, 403),
               where

        response = get_in(document, ["paths", path, to_string(route.verb), "responses", "403"])
        operation = Map.fetch!(spec.paths[path], route.verb)
        assert_body(conn, operation.responses[403], response, spec, document, where)
      end
    end
  end

  # -- the requests -----------------------------------------------------------

  defp seed(_ctx) do
    {:ok, _result} = Rephi.Seeds.run(admin_email: nil, admin_password: nil, admin: :optional)

    {admin, admin_token} = create_user_with_token_and(roles: ["admin"])
    {_nobody, nobody_token} = create_user_with_token()
    {:ok, reset, _password} = Accounts.reset_password(create_user())
    {:ok, reset_token, _claims} = RephiWeb.Auth.Guardian.encode_and_sign(reset)

    # child inherits `inherited` from parent; nothing is assigned to child.
    parent = create_role()
    child = create_role()
    {:ok, _} = Authorization.assign_parent_role(child, parent)
    inherited = create_permission()
    {:ok, _} = Authorization.assign_permission_to_role(parent, inherited)

    on_exit(fn -> RateLimiter.reset() end)

    %{
      admin: admin,
      token: admin_token,
      nobody_token: nobody_token,
      reset_token: reset_token,
      parent: parent,
      child: child,
      inherited: inherited
    }
  end

  defp cases(%{token: token} = ctx) do
    admin_role = Authorization.get_role_by_slug("admin")
    manager_role = Authorization.get_role_by_slug("manager")
    system_permission = Authorization.get_permission_by_slug("users:view")

    [
      {"get", "/", 200, fn -> call(:get, "/") end},
      {"get", "/api/health", 200, fn -> call(:get, "/api/health") end},
      {"get", "/api/health/ready", 200, fn -> call(:get, "/api/health/ready") end},
      {"get", "/api/openapi", 200, fn -> call(:get, "/api/openapi") end},
      {"get", "/api/openapi", 404,
       fn ->
         Application.put_env(:rephi, :swagger_enabled, false)

         try do
           call(:get, "/api/openapi")
         after
           Application.put_env(:rephi, :swagger_enabled, true)
         end
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
      {"post", "/api/notifications/me", 200,
       fn -> call(:post, "/api/notifications/me", ctx.nobody_token, %{message: "Hi me"}) end},
      {"post", "/api/notifications/me", 422,
       fn -> call(:post, "/api/notifications/me", ctx.nobody_token, %{message: ""}) end},

      # Dashboard
      {"get", "/api/dashboard", 200, fn -> call(:get, "/api/dashboard", token) end},

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
      {"get", "/api/roles/{id}/parents", 200,
       fn -> call(:get, "/api/roles/#{ctx.child.id}/parents", token) end},
      {"get", "/api/roles/{id}/children", 200,
       fn -> call(:get, "/api/roles/#{ctx.parent.id}/children", token) end},
      {"post", "/api/roles/{role_id}/parents/{parent_id}", 201,
       fn ->
         call(:post, "/api/roles/#{create_role().id}/parents/#{ctx.parent.id}", token, %{
           notes: "Editors can do what authors do"
         })
       end},
      {"post", "/api/roles/{role_id}/parents/{parent_id}", 409,
       fn -> call(:post, "/api/roles/#{ctx.parent.id}/parents/#{ctx.child.id}", token) end},
      {"post", "/api/roles/{role_id}/parents/{parent_id}", 422,
       fn ->
         call(:post, "/api/roles/#{create_role().id}/parents/#{ctx.parent.id}", token, %{
           notes: 1
         })
       end},
      {"delete", "/api/roles/{role_id}/parents/{parent_id}", 204,
       fn ->
         {child, parent} = {create_role(), create_role()}
         {:ok, _} = Authorization.assign_parent_role(child, parent)
         call(:delete, "/api/roles/#{child.id}/parents/#{parent.id}", token)
       end},
      {"delete", "/api/roles/{role_id}/parents/{parent_id}", 409,
       fn -> call(:delete, "/api/roles/#{admin_role.id}/parents/#{manager_role.id}", token) end},

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
       fn -> call(:get, "/api/users/#{ctx.admin.id}/roles", token) end},
      {"get", "/api/users/{id}/permissions", 200,
       fn ->
         user = create_user()
         grant_role(user, "manager")
         grant_permission(user, ctx.inherited.slug)
         call(:get, "/api/users/#{user.id}/permissions", token)
       end},
      {"post", "/api/users/{id}/password", 200,
       fn -> call(:post, "/api/users/#{create_user().id}/password", token) end},
      {"post", "/api/users/{id}/password", 409,
       fn -> call(:post, "/api/users/#{ctx.admin.id}/password", token) end},
      {"post", "/api/users/{user_id}/permissions/{permission_id}", 201,
       fn ->
         path = "/api/users/#{create_user().id}/permissions/#{system_permission.id}"
         call(:post, path, token, %{notes: "Audit"})
       end},
      {"post", "/api/users/{user_id}/permissions/{permission_id}", 409,
       fn ->
         user = create_user()
         grant_permission(user, system_permission.slug)
         call(:post, "/api/users/#{user.id}/permissions/#{system_permission.id}", token)
       end},
      {"post", "/api/users/{user_id}/permissions/{permission_id}", 422,
       fn ->
         path = "/api/users/#{create_user().id}/permissions/#{system_permission.id}"
         call(:post, path, token, %{notes: []})
       end},
      {"delete", "/api/users/{user_id}/permissions/{permission_id}", 204,
       fn ->
         user = create_user()
         grant_permission(user, system_permission.slug)
         call(:delete, "/api/users/#{user.id}/permissions/#{system_permission.id}", token)
       end},
      {"delete", "/api/users/{user_id}/permissions/{permission_id}", 409,
       fn ->
         user = create_user()
         grant_role(user, "manager")
         call(:delete, "/api/users/#{user.id}/permissions/#{system_permission.id}", token)
       end}
    ]
  end

  # The responses every operation of a kind answers the same way, derived
  # from what the document declares.
  defp generic_cases(%{token: token} = ctx, document) do
    for {verb, path, op} <- operations(document),
        status <- Map.keys(op["responses"]) |> Enum.map(&String.to_integer/1),
        status != 401 or op["security"] != nil,
        request = generic_request(status, verb, path, token, forbidden_token(op, ctx)),
        request != nil,
        do: {verb, path, status, request}
  end

  # Without a permission check, the only 403 of a route is the password gate's.
  defp forbidden_token(op, ctx) do
    case get_in(op, ["responses", "403", "description"]) do
      "Forbidden - the caller's password was reset" <> _ -> ctx.reset_token
      _other -> ctx.nobody_token
    end
  end

  defp generic_request(401, verb, path, _token, _nobody) do
    fn -> call(verb, fill(path, 1)) end
  end

  defp generic_request(403, verb, path, _token, forbidden_token) do
    fn -> call(verb, fill(path, 1), forbidden_token, %{}) end
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
        register: [limit: 1, window_seconds: 60],
        self_notification: [limit: 1, window_seconds: 60]
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

  # -- the document -----------------------------------------------------------

  defp document, do: RephiWeb.ApiSpec.spec() |> Jason.encode!() |> Jason.decode!()

  defp controller_routes do
    for route <- RephiWeb.Router.__routes__(),
        is_atom(route.plug_opts),
        match?(["RephiWeb" | _], Module.split(route.plug)),
        Code.ensure_loaded?(route.plug),
        do: route
  end

  defp gated?(route) do
    verb = route.verb |> to_string() |> String.upcase()
    path = Regex.replace(~r/:[^\/]+/, route.path, "1")
    info = Phoenix.Router.route_info(RephiWeb.Router, verb, path, "www.example.com")
    :password_settled in info.pipe_through
  end

  defp open_api_path(path), do: Regex.replace(~r/:([^\/]+)/, path, "{\\1}")

  defp operations(document) do
    for {path, verbs} <- document["paths"], {verb, op} <- verbs, do: {verb, path, op}
  end

  defp refs(%{"$ref" => ref}), do: [ref]
  defp refs(map) when is_map(map), do: Enum.flat_map(Map.values(map), &refs/1)
  defp refs(list) when is_list(list), do: Enum.flat_map(list, &refs/1)
  defp refs(_other), do: []

  defp ref_path("#/" <> pointer), do: String.split(pointer, "/")

  defp response_schemas(document) do
    roots =
      for {verb, path, op} <- operations(document),
          {status, response} <- op["responses"],
          %{"schema" => schema} <- Map.values(response["content"] || %{}),
          do: {"#{String.upcase(verb)} #{path} #{status}", schema}

    schemas = document["components"]["schemas"]
    refs = roots |> Enum.flat_map(fn {_where, schema} -> refs(schema) end)

    components =
      for name <- reachable(refs, schemas, MapSet.new()), do: {name, schemas[name]}

    roots ++ components
  end

  defp reachable([], _schemas, seen), do: seen

  defp reachable(["#/components/schemas/" <> name | rest], schemas, seen) do
    if name in seen do
      reachable(rest, schemas, seen)
    else
      reachable(refs(schemas[name]) ++ rest, schemas, MapSet.put(seen, name))
    end
  end

  defp objects(%{"properties" => properties} = schema, where) do
    nested = for {key, property} <- properties, do: objects(property, "#{where}.#{key}")
    [{where, schema} | List.flatten(nested)]
  end

  defp objects(%{"items" => items}, where), do: objects(items, "#{where}[]")
  defp objects(_schema, _where), do: []

  # additionalProperties: false, so casting fails on an undeclared field.
  defp strict(%OpenApiSpex.OpenApi{} = spec) do
    schemas = Map.new(spec.components.schemas, fn {name, schema} -> {name, strict(schema)} end)
    put_in(spec.components.schemas, schemas)
  end

  defp strict(%Schema{} = schema) do
    schema = %{
      schema
      | properties: schema.properties && Map.new(schema.properties, &strict_property/1),
        items: strict(schema.items)
    }

    if schema.type == :object and schema.properties != nil and
         schema.additionalProperties == nil,
       do: %{schema | additionalProperties: false},
       else: schema
  end

  defp strict(other), do: other

  defp strict_property({key, schema}), do: {key, strict(schema)}

  # -- the response against the schema ----------------------------------------

  defp assert_body(conn, %{content: nil}, _response, _spec, _document, where) do
    assert conn.resp_body == "", "#{where}: documented without a body, got #{conn.resp_body}"
  end

  defp assert_body(conn, %{content: content}, response, spec, document, where) do
    assert ["application/json" <> _] = get_resp_header(conn, "content-type")
    body = Jason.decode!(conn.resp_body)

    case OpenApiSpex.cast_value(body, content["application/json"].schema, spec) do
      {:ok, _cast} ->
        :ok

      {:error, errors} ->
        messages =
          Enum.map_join(errors, "; ", &"#{Error.message(&1)} at #{Error.path_to_string(&1)}")

        flunk("#{where}: #{messages}\n#{conn.resp_body}")
    end

    assert_types(body, response["content"]["application/json"]["schema"], document, where)
  end

  # Casting accepts "1" for an integer and "true" for a boolean: check JSON types.
  defp assert_types(value, %{"$ref" => ref}, document, where) do
    assert_types(value, get_in(document, ref_path(ref)), document, "#{where} (#{ref})")
  end

  defp assert_types(nil, %{"nullable" => true}, _document, _where), do: :ok

  defp assert_types(value, %{"type" => "object"} = schema, document, where) do
    assert is_map(value), "#{where}: expected an object, got #{inspect(value)}"

    for {key, item} <- value do
      case schema do
        %{"properties" => %{^key => property}} ->
          assert_types(item, property, document, "#{where}.#{key}")

        %{"additionalProperties" => %{} = property} ->
          assert_types(item, property, document, "#{where}.#{key}")

        _free_form ->
          :ok
      end
    end
  end

  defp assert_types(value, %{"type" => "array", "items" => items}, document, where) do
    assert is_list(value), "#{where}: expected an array, got #{inspect(value)}"
    for item <- value, do: assert_types(item, items, document, "#{where}[]")
  end

  defp assert_types(value, %{"type" => type} = schema, _document, where) do
    assert scalar?(type, value), "#{where}: expected #{type}, got #{inspect(value)}"

    if schema["format"] == "date-time" do
      assert {:ok, _datetime, 0} = DateTime.from_iso8601(value), "#{where}: not a UTC date-time"
    end
  end

  defp scalar?("integer", value), do: is_integer(value)
  defp scalar?("string", value), do: is_binary(value)
  defp scalar?("boolean", value), do: is_boolean(value)
  defp scalar?(_type, _value), do: false
end
