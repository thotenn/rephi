defmodule RephiWeb.RoleHierarchyTest do
  @moduledoc """
  The role hierarchy over the API: `GET /api/roles/:id/parents`,
  `GET /api/roles/:id/children`, `POST` and `DELETE
  /api/roles/:role_id/parents/:parent_id`.
  """
  use RephiWeb.ConnCase

  alias Rephi.{Authorization, Seeds}

  setup %{conn: conn} do
    {:ok, _} = Seeds.run(admin_email: nil, admin_password: nil, admin: :optional)
    {admin, admin_token} = create_user_with_token_and(roles: ["admin"])
    {_manager, manager_token} = create_user_with_token_and(roles: ["manager"])

    %{
      admin: admin,
      admin_role: Authorization.get_role_by_slug("admin"),
      manager_role: Authorization.get_role_by_slug("manager"),
      user_role: Authorization.get_role_by_slug("user"),
      as_admin: authenticate_conn(conn, admin_token),
      as_manager: authenticate_conn(conn, manager_token)
    }
  end

  defp parents_path(role), do: "/api/roles/#{role.id}/parents"
  defp link_path(role, parent), do: "/api/roles/#{role.id}/parents/#{parent.id}"
  defp slugs(conn), do: conn |> json_response(200) |> Map.fetch!("data") |> Enum.map(& &1["slug"])

  describe "GET parents and children" do
    test "the direct links of a role, by slug, with the link", ctx do
      assert [parent] =
               ctx.as_manager
               |> get(parents_path(ctx.admin_role))
               |> json_response(200)
               |> Map.fetch!("data")

      assert %{
               "id" => id,
               "slug" => "manager",
               "name" => "Manager",
               "description" => _,
               "is_system" => true,
               "system_link" => true,
               "assigned_by" => nil,
               "notes" => nil,
               "linked_at" => "20" <> _
             } = parent

      assert id == ctx.manager_role.id

      assert slugs(get(ctx.as_manager, "/api/roles/#{ctx.manager_role.id}/children")) == ["admin"]
      assert slugs(get(ctx.as_manager, "/api/roles/#{ctx.user_role.id}/children")) == ["manager"]
      assert slugs(get(ctx.as_manager, parents_path(ctx.user_role))) == []
    end

    test "need roles:view; unknown ids are a 404", ctx do
      {_u, token} = create_user_with_token_and(roles: ["user"])

      for path <- [parents_path(ctx.admin_role), "/api/roles/#{ctx.admin_role.id}/children"] do
        assert build_conn() |> authenticate_conn(token) |> get(path) |> error_detail(403) ==
                 "Forbidden"
      end

      for id <- invalid_ids() do
        assert ctx.as_admin |> get("/api/roles/#{id}/parents") |> error_detail(404) == "Not Found"

        assert ctx.as_admin |> get("/api/roles/#{id}/children") |> error_detail(404) ==
                 "Not Found"
      end
    end
  end

  describe "POST /api/roles/:role_id/parents/:parent_id" do
    test "links a parent: the child's holders get its permissions", ctx do
      child = create_role()
      parent = create_role()
      permission = create_permission()
      {:ok, _} = Authorization.assign_permission_to_role(parent, permission)
      holder = create_user()
      grant_role(holder, child.slug)
      refute Authorization.can?(holder, permission.slug)

      conn = post(ctx.as_admin, link_path(child, parent), %{notes: "Inherits the parent"})

      assert json_response(conn, 201)["data"] == %{
               "role_id" => child.id,
               "parent_id" => parent.id,
               "is_system" => false,
               "assigned_by" => ctx.admin.id,
               "notes" => "Inherits the parent",
               "inserted_at" => json_response(conn, 201)["data"]["inserted_at"]
             }

      assert Authorization.can?(holder, permission.slug)

      [inherited] =
        ctx.as_admin
        |> get("/api/roles/#{child.id}")
        |> json_response(200)
        |> get_in(["data", "inherited_permissions"])

      assert inherited["slug"] == permission.slug
      assert [%{"id" => parent_id}] = inherited["inherited_from"]
      assert parent_id == parent.id

      assert [
               %{
                 "assigned_by" => admin_id,
                 "notes" => "Inherits the parent",
                 "system_link" => false
               }
             ] =
               ctx.as_admin
               |> get(parents_path(child))
               |> json_response(200)
               |> Map.fetch!("data")

      assert admin_id == ctx.admin.id
    end

    test "the body is optional and may be wrapped", ctx do
      assert json_response(post(ctx.as_admin, link_path(create_role(), create_role())), 201)

      assert %{"notes" => "wrapped"} =
               ctx.as_admin
               |> post(link_path(create_role(), create_role()), %{notes: "wrapped"})
               |> json_response(201)
               |> Map.fetch!("data")
    end

    test "a cycle, a self link and a duplicate are 409; the cycle is not stored", ctx do
      [a, b, c] = for _ <- 1..3, do: create_role()
      assert json_response(post(ctx.as_admin, link_path(b, a)), 201)
      assert json_response(post(ctx.as_admin, link_path(c, b)), 201)

      assert ctx.as_admin |> post(link_path(a, c)) |> error_detail(409) ==
               "The role would inherit from itself"

      assert ctx.as_admin |> post(link_path(a, a)) |> error_detail(409) ==
               "The role would inherit from itself"

      assert ctx.as_admin |> post(link_path(ctx.user_role, ctx.admin_role)) |> error_detail(409) ==
               "The role would inherit from itself"

      assert ctx.as_admin |> post(link_path(b, a)) |> error_detail(409) ==
               "The role already inherits from this parent"

      assert slugs(get(ctx.as_admin, parents_path(a))) == []
    end

    test "invalid notes are a 422", ctx do
      conn = post(ctx.as_admin, link_path(create_role(), create_role()), %{notes: 1})
      assert %{"errors" => %{"notes" => [_]}} = json_response(conn, 422)

      conn =
        post(ctx.as_admin, link_path(create_role(), create_role()), %{
          notes: String.duplicate("x", 2001)
        })

      assert %{"errors" => %{"notes" => ["should be at most 2000 character(s)"]}} =
               json_response(conn, 422)
    end

    test "needs roles:edit", ctx do
      [child, parent] = for _ <- 1..2, do: create_role()

      assert ctx.as_manager |> post(link_path(child, parent)) |> error_detail(403) == "Forbidden"
      assert Authorization.list_parent_roles(child) == []
    end

    test "a non-admin must hold both roles (escalation)", %{conn: conn} do
      [held, also_held, not_held] = for _ <- 1..3, do: create_role()

      {_u, token} =
        create_user_with_token_and(
          roles: [held.slug, also_held.slug],
          permissions: ["roles:edit"]
        )

      conn = authenticate_conn(conn, token)
      escalation = "You can only grant or revoke roles and permissions you hold"

      assert conn |> post(link_path(held, not_held)) |> error_detail(403) == escalation
      assert conn |> post(link_path(not_held, held)) |> error_detail(403) == escalation
      admin_role = Authorization.get_role_by_slug("admin")
      assert conn |> post(link_path(admin_role, held)) |> error_detail(403) == escalation
      assert conn |> post(link_path(held, admin_role)) |> error_detail(403) == escalation

      assert json_response(post(conn, link_path(held, also_held)), 201)
    end

    test "unknown ids are a 404", ctx do
      role = create_role()

      for id <- invalid_ids() do
        assert ctx.as_admin |> post("/api/roles/#{id}/parents/#{role.id}") |> error_detail(404)
        assert ctx.as_admin |> post("/api/roles/#{role.id}/parents/#{id}") |> error_detail(404)
      end
    end
  end

  describe "DELETE /api/roles/:role_id/parents/:parent_id" do
    test "unlinks a parent: its permissions stop being inherited", ctx do
      [child, parent] = for _ <- 1..2, do: create_role()
      permission = create_permission()
      {:ok, _} = Authorization.assign_permission_to_role(parent, permission)
      {:ok, _} = Authorization.assign_parent_role(child, parent)
      holder = create_user()
      grant_role(holder, child.slug)
      assert Authorization.can?(holder, permission.slug)

      assert ctx.as_admin |> delete(link_path(child, parent)) |> response(204) == ""
      refute Authorization.can?(holder, permission.slug)

      assert ctx.as_admin |> delete(link_path(child, parent)) |> error_detail(404) == "Not Found"
    end

    test "the links of the seeded hierarchy are system links (409)", ctx do
      for {child, parent} <- [
            {ctx.admin_role, ctx.manager_role},
            {ctx.manager_role, ctx.user_role}
          ] do
        assert ctx.as_admin |> delete(link_path(child, parent)) |> error_detail(409) ==
                 "Links of the default role hierarchy cannot be removed"
      end

      assert slugs(get(ctx.as_admin, parents_path(ctx.admin_role))) == ["manager"]
    end

    test "unlinking the path through which the last admins hold the admin role is a 409", ctx do
      super_role = create_role()
      {:ok, _} = Authorization.assign_parent_role(super_role, ctx.admin_role)
      {super_user, super_token} = create_user_with_token_and(roles: [super_role.slug])
      :ok = Authorization.remove_role_from_user(ctx.admin, ctx.admin_role)
      assert Authorization.admin?(super_user)

      as_super = authenticate_conn(build_conn(), super_token)

      assert as_super |> delete(link_path(super_role, ctx.admin_role)) |> error_detail(409) ==
               "At least one user must keep the admin role"

      assert Authorization.admin?(super_user)
    end

    test "needs roles:edit, and a non-admin must hold both roles", %{conn: conn} = ctx do
      [held, not_held] = for _ <- 1..2, do: create_role()
      {:ok, _} = Authorization.assign_parent_role(held, not_held)

      assert ctx.as_manager |> delete(link_path(held, not_held)) |> error_detail(403) ==
               "Forbidden"

      {_u, token} = create_user_with_token_and(roles: [held.slug], permissions: ["roles:edit"])

      # `held` inherits from `not_held`, so the user holds both.
      assert conn
             |> authenticate_conn(token)
             |> delete(link_path(held, not_held))
             |> response(204)

      other = create_role()
      {:ok, _} = Authorization.assign_parent_role(other, held)

      assert conn
             |> authenticate_conn(token)
             |> delete(link_path(other, held))
             |> error_detail(403) ==
               "You can only grant or revoke roles and permissions you hold"
    end

    test "unknown ids are a 404", ctx do
      role = create_role()

      for id <- invalid_ids() do
        assert ctx.as_admin |> delete("/api/roles/#{id}/parents/#{role.id}") |> error_detail(404)
        assert ctx.as_admin |> delete("/api/roles/#{role.id}/parents/#{id}") |> error_detail(404)
      end
    end
  end
end
