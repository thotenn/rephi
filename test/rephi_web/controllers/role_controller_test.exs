defmodule RephiWeb.RoleControllerTest do
  use RephiWeb.ConnCase

  alias Rephi.Authorization

  @permissions ~w(roles:view roles:create roles:edit roles:delete roles:assign)

  setup %{conn: conn} do
    {user, token} = create_user_with_token_and(permissions: @permissions, roles: ["admin"])
    {:ok, conn: authenticate_conn(conn, token), user: user}
  end

  describe "authorization" do
    test "every route answers 401 without a token" do
      for {method, path} <- routes(1, 1) do
        conn = dispatch(build_conn(), @endpoint, method, path)

        assert error_detail(conn, 401) == "Authentication required",
               "unexpected response for #{method} #{path}"
      end
    end

    test "every route answers 403 without the permission" do
      {_user, token} = create_user_with_token()

      for {method, path} <- routes(1, 1) do
        conn = build_conn() |> authenticate_conn(token) |> dispatch(@endpoint, method, path)

        assert error_detail(conn, 403) == "Forbidden",
               "unexpected response for #{method} #{path}"
      end
    end
  end

  describe "index/2" do
    test "lists roles", %{conn: conn} do
      role = create_role(%{name: "Editor", slug: "editor", description: "Edits"})

      assert %{"data" => roles} = conn |> get(~p"/api/roles") |> json_response(200)

      assert %{
               "id" => role.id,
               "name" => "Editor",
               "slug" => "editor",
               "description" => "Edits"
             } ==
               roles
               |> Enum.find(&(&1["id"] == role.id))
               |> Map.take(~w(id name slug description))
    end
  end

  describe "show/2" do
    test "renders the role with its permissions", %{conn: conn} do
      role = create_role(%{name: "Editor", slug: "editor"})
      permission = create_permission(%{name: "Edit posts", slug: "posts:edit"})
      {:ok, _} = Authorization.assign_permission_to_role(role, permission)

      assert %{"data" => data} = conn |> get(~p"/api/roles/#{role}") |> json_response(200)
      assert %{"id" => _, "name" => "Editor", "slug" => "editor"} = data

      assert data["permissions"] == [
               %{
                 "id" => permission.id,
                 "name" => "Edit posts",
                 "slug" => "posts:edit",
                 "description" => nil
               }
             ]
    end
  end

  describe "create/2" do
    test "creates a role from a flat body", %{conn: conn} do
      conn = post(conn, ~p"/api/roles", %{name: "Editor", slug: "editor", description: "Edits"})

      assert %{
               "data" => %{
                 "id" => id,
                 "name" => "Editor",
                 "slug" => "editor",
                 "permissions" => []
               }
             } =
               json_response(conn, 201)

      assert get_resp_header(conn, "location") == ["/api/roles/#{id}"]
      assert Authorization.get_role(id).description == "Edits"
    end

    test "creates a role from a body wrapped under \"role\"", %{conn: conn} do
      conn = post(conn, ~p"/api/roles", %{role: %{name: "Editor", slug: "editor"}})

      assert %{"data" => %{"slug" => "editor"}} = json_response(conn, 201)
    end

    test "says which fields are invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/roles", %{name: "", slug: "Bad Slug!"})

      assert %{"errors" => %{"name" => ["can't be blank"], "slug" => [_ | _]}} =
               json_response(conn, 422)
    end

    test "says the slug is taken", %{conn: conn} do
      create_role(%{slug: "editor"})

      conn = post(conn, ~p"/api/roles", %{name: "Editor", slug: "editor"})

      assert json_response(conn, 422) == %{"errors" => %{"slug" => ["has already been taken"]}}
    end

    test "answers 422, not 400, to a body without the attributes", %{conn: conn} do
      for body <- [%{}, %{role: "x"}, %{role: %{}}, %{unknown: 1}] do
        conn = post(conn, ~p"/api/roles", body)

        assert %{"errors" => %{"name" => ["can't be blank"], "slug" => ["can't be blank"]}} =
                 json_response(conn, 422)
      end
    end
  end

  describe "update/2" do
    test "updates a role from a flat or a wrapped body", %{conn: conn} do
      role = create_role(%{name: "Editor", slug: "editor"})

      assert %{"data" => %{"name" => "Flat", "slug" => "editor", "permissions" => []}} =
               conn |> put(~p"/api/roles/#{role}", %{name: "Flat"}) |> json_response(200)

      assert %{"data" => %{"name" => "Wrapped"}} =
               conn
               |> patch(~p"/api/roles/#{role}", %{role: %{name: "Wrapped"}})
               |> json_response(200)
    end

    test "says which fields are invalid", %{conn: conn} do
      role = create_role()
      create_role(%{slug: "taken"})

      conn = put(conn, ~p"/api/roles/#{role}", %{slug: "taken"})

      assert json_response(conn, 422) == %{"errors" => %{"slug" => ["has already been taken"]}}
    end
  end

  describe "delete/2" do
    test "deletes the role", %{conn: conn} do
      role = create_role()

      assert conn |> delete(~p"/api/roles/#{role}") |> response(204) == ""
      assert Authorization.get_role(role.id) == nil
    end
  end

  describe "get_role_permissions/2" do
    test "lists the permissions of the role", %{conn: conn} do
      role = create_role()
      permission = create_permission(%{slug: "posts:edit"})
      {:ok, _} = Authorization.assign_permission_to_role(role, permission)

      assert %{"data" => [%{"id" => id, "slug" => "posts:edit"}]} =
               conn |> get(~p"/api/roles/#{role}/permissions") |> json_response(200)

      assert id == permission.id
    end
  end

  describe "assign_to_user/2" do
    test "returns the assignment that was created", %{conn: conn, user: admin} do
      user = create_user()
      role = create_role()

      conn = post(conn, ~p"/api/users/#{user.id}/roles/#{role.id}", %{notes: "Promoted"})

      assert %{
               "data" => %{
                 "user_id" => user_id,
                 "role_id" => role_id,
                 "assigned_by" => assigned_by,
                 "notes" => "Promoted",
                 "inserted_at" => _
               }
             } = json_response(conn, 201)

      assert {user_id, role_id, assigned_by} == {user.id, role.id, admin.id}
      assert Authorization.has_role?(user, role)
    end

    test "works without a body", %{conn: conn} do
      user = create_user()
      role = create_role()

      conn = post(conn, ~p"/api/users/#{user.id}/roles/#{role.id}")

      assert %{"data" => %{"notes" => nil}} = json_response(conn, 201)
    end

    test "answers 409 when the user already has the role", %{conn: conn} do
      user = create_user()
      role = create_role()
      {:ok, _} = Authorization.assign_role_to_user(user, role)

      conn = post(conn, ~p"/api/users/#{user.id}/roles/#{role.id}")

      assert error_detail(conn, 409) == "Role already assigned to user"
    end

    test "answers 422 when the notes are not text", %{conn: conn} do
      user = create_user()
      role = create_role()

      conn = post(conn, ~p"/api/users/#{user.id}/roles/#{role.id}", %{notes: %{a: 1}})

      assert json_response(conn, 422) == %{"errors" => %{"notes" => ["is invalid"]}}
    end
  end

  describe "remove_from_user/2" do
    test "removes the role and answers 404 once it is gone", %{conn: conn} do
      user = create_user()
      role = grant_role(user, "editor")

      assert conn |> delete(~p"/api/users/#{user.id}/roles/#{role.id}") |> response(204) == ""
      refute Authorization.has_role?(user, role)

      conn = delete(conn, ~p"/api/users/#{user.id}/roles/#{role.id}")
      assert error_detail(conn, 404) == "Not Found"
    end
  end

  describe "ids" do
    test "an unknown or invalid id is a 404 on every route", %{conn: conn} do
      user = create_user()
      role = create_role()

      for id <- ["999999" | invalid_ids()],
          {method, path} <- routes(id, id) ++ routes(user.id, id) ++ routes(id, role.id),
          String.contains?(path, "/#{id}") do
        conn = dispatch(conn, @endpoint, method, path, %{name: "x"})

        assert error_detail(conn, 404) == "Not Found",
               "unexpected response for #{method} #{path}"
      end
    end
  end

  describe "pagination and shape (RBAC-18, RBAC-21)" do
    test "ordered by slug, with meta; is_system and UTC timestamps", %{conn: conn} do
      for slug <- ~w(zeta alpha mid), do: create_role(%{slug: slug})

      assert %{"data" => roles, "meta" => meta} =
               conn |> get(~p"/api/roles?page_size=2") |> json_response(200)

      slugs = Enum.map(roles, & &1["slug"])
      assert slugs == Enum.sort(slugs)
      assert length(roles) == 2
      assert %{"page" => 1, "page_size" => 2, "total" => total} = meta
      assert total >= 4

      assert %{"is_system" => false, "inserted_at" => at} = hd(roles)
      assert at =~ ~r/Z\z/
    end
  end

  describe "direct and inherited permissions (RBAC-16)" do
    setup do
      parent = create_role(%{slug: "parent"})
      child = create_role(%{slug: "child"})
      {:ok, _} = Authorization.assign_parent_role(child, parent)
      inherited = create_permission(%{slug: "posts:view"})
      own = create_permission(%{slug: "posts:edit"})
      {:ok, _} = Authorization.assign_permission_to_role(parent, inherited)
      {:ok, _} = Authorization.assign_permission_to_role(child, own)
      {:ok, parent: parent, child: child, inherited: inherited, own: own}
    end

    test "show separates them, and says where the inherited ones come from", ctx do
      assert %{"data" => data} =
               ctx.conn |> get(~p"/api/roles/#{ctx.child}") |> json_response(200)

      assert [%{"slug" => "posts:edit"}] = data["permissions"]

      assert [
               %{
                 "slug" => "posts:view",
                 "inherited_from" => [%{"id" => parent_id, "slug" => "parent", "name" => _}]
               }
             ] = data["inherited_permissions"]

      assert parent_id == ctx.parent.id
    end

    test "the permissions route lists both, flagged", ctx do
      assert %{"data" => [edit, view]} =
               ctx.conn |> get(~p"/api/roles/#{ctx.child}/permissions") |> json_response(200)

      assert %{"slug" => "posts:edit", "inherited" => false, "inherited_from" => []} = edit
      assert %{"slug" => "posts:view", "inherited" => true, "inherited_from" => [_]} = view
    end

    test "revoking an inherited permission is a 409, not a 404", ctx do
      {_u, token} =
        create_user_with_token_and(permissions: ["permissions:assign"], roles: ["admin"])

      conn =
        build_conn()
        |> authenticate_conn(token)
        |> delete(~p"/api/roles/#{ctx.child.id}/permissions/#{ctx.inherited.id}")

      assert error_detail(conn, 409) ==
               "The role inherits this permission from a parent role; revoke it from that role"
    end
  end

  describe "system roles and the last admin (RBAC-04)" do
    setup %{user: user} do
      {:ok, _} = Rephi.Seeds.run(admin_email: nil, admin_password: nil, admin: :optional)
      {:ok, admin_role: Authorization.get_role_by_slug("admin"), me: user}
    end

    test "a system role cannot be deleted nor renamed by slug", %{conn: conn} do
      manager = Authorization.get_role_by_slug("manager")

      assert conn |> delete(~p"/api/roles/#{manager}") |> error_detail(409) ==
               "System roles cannot be deleted"

      assert conn |> put(~p"/api/roles/#{manager}", %{slug: "boss"}) |> json_response(422) == %{
               "errors" => %{"slug" => ["cannot be changed on a system role"]}
             }

      assert %{"data" => %{"name" => "Boss", "is_system" => true}} =
               conn |> put(~p"/api/roles/#{manager}", %{name: "Boss"}) |> json_response(200)

      assert Authorization.get_role(manager.id)
    end

    test "the last admin cannot remove the role from itself", ctx do
      path = ~p"/api/users/#{ctx.me.id}/roles/#{ctx.admin_role.id}"

      assert ctx.conn |> delete(path) |> error_detail(409) ==
               "At least one user must keep the admin role"

      other = create_user()
      {:ok, _} = Authorization.assign_role_to_user(other, ctx.admin_role)
      assert ctx.conn |> delete(path) |> response(204)
    end
  end

  describe "no escalation (RBAC-05)" do
    setup %{conn: conn} do
      {:ok, _} = Rephi.Seeds.run(admin_email: nil, admin_password: nil, admin: :optional)

      {helpdesk, token} =
        create_user_with_token_and(permissions: ["roles:assign"], roles: ["user"])

      {:ok, helpdesk: helpdesk, as_helpdesk: authenticate_conn(conn, token)}
    end

    test "roles:assign alone cannot hand out a role the caller does not hold", ctx do
      admin_role = Authorization.get_role_by_slug("admin")
      user_role = Authorization.get_role_by_slug("user")
      target = create_user()

      conn = post(ctx.as_helpdesk, ~p"/api/users/#{ctx.helpdesk.id}/roles/#{admin_role.id}")

      assert error_detail(conn, 403) ==
               "You can only grant or revoke roles and permissions you hold"

      refute Authorization.has_role?(ctx.helpdesk, "admin")

      assert ctx.as_helpdesk
             |> post(~p"/api/users/#{target.id}/roles/#{user_role.id}")
             |> json_response(201)

      {:ok, _} = Authorization.assign_role_to_user(target, admin_role)

      assert ctx.as_helpdesk
             |> delete(~p"/api/users/#{target.id}/roles/#{admin_role.id}")
             |> error_detail(403) =~ "you hold"
    end
  end

  defp routes(user_id, role_id) do
    [
      {:get, "/api/roles/#{role_id}"},
      {:put, "/api/roles/#{role_id}"},
      {:patch, "/api/roles/#{role_id}"},
      {:delete, "/api/roles/#{role_id}"},
      {:get, "/api/roles/#{role_id}/permissions"},
      {:post, "/api/users/#{user_id}/roles/#{role_id}"},
      {:delete, "/api/users/#{user_id}/roles/#{role_id}"}
    ]
  end
end
