defmodule RephiWeb.UserPermissionsTest do
  @moduledoc """
  Permissions granted to users directly, over the API:
  `GET /api/users/:id/permissions`, `POST` and `DELETE
  /api/users/:user_id/permissions/:permission_id`.
  """
  use RephiWeb.ConnCase

  alias Rephi.{Authorization, Seeds}

  setup %{conn: conn} do
    {:ok, _} = Seeds.run(admin_email: nil, admin_password: nil, admin: :optional)
    {admin, admin_token} = create_user_with_token_and(roles: ["admin"])
    {_manager, manager_token} = create_user_with_token_and(roles: ["manager"])
    {target, target_token} = create_user_with_token_and(roles: ["user"])

    %{
      admin: admin,
      target: target,
      as_admin: authenticate_conn(conn, admin_token),
      as_manager: authenticate_conn(conn, manager_token),
      as_target: authenticate_conn(conn, target_token),
      roles_view: Authorization.get_permission_by_slug("roles:view"),
      users_view: Authorization.get_permission_by_slug("users:view")
    }
  end

  defp grant_path(user, permission), do: "/api/users/#{user.id}/permissions/#{permission.id}"

  defp permissions(conn, user),
    do:
      conn |> get("/api/users/#{user.id}/permissions") |> json_response(200) |> Map.fetch!("data")

  describe "GET /api/users/:id/permissions" do
    test "direct grants, and every effective permission with its source", ctx do
      {:ok, _} =
        Authorization.assign_permission_to_user(ctx.target, ctx.roles_view,
          assigned_by: ctx.admin.id,
          notes: "Audit"
        )

      user = create_user()
      grant_role(user, "manager")
      {:ok, _} = Authorization.assign_permission_to_user(user, ctx.users_view)

      assert %{"direct" => [direct], "effective" => [effective]} =
               permissions(ctx.as_manager, ctx.target)

      assert %{
               "id" => id,
               "slug" => "roles:view",
               "name" => "View Roles",
               "description" => _,
               "assigned_by" => admin_id,
               "notes" => "Audit",
               "granted_at" => "20" <> _
             } = direct

      assert {id, admin_id} == {ctx.roles_view.id, ctx.admin.id}
      assert %{"slug" => "roles:view", "direct" => true, "roles" => []} = effective

      %{"direct" => [_], "effective" => effective} = permissions(ctx.as_admin, user)
      by_slug = Map.new(effective, &{&1["slug"], &1})

      assert %{"direct" => true, "roles" => [%{"slug" => "manager"}]} = by_slug["users:view"]

      assert %{"direct" => false, "roles" => [%{"slug" => "manager", "id" => _, "name" => _}]} =
               by_slug["roles:view"]

      assert Enum.map(effective, & &1["slug"]) == Enum.sort(Map.keys(by_slug))
    end

    test "needs users:view; unknown ids are a 404", ctx do
      assert ctx.as_target |> get("/api/users/#{ctx.admin.id}/permissions") |> error_detail(403) ==
               "Forbidden"

      for id <- invalid_ids() do
        assert ctx.as_admin |> get("/api/users/#{id}/permissions") |> error_detail(404) ==
                 "Not Found"
      end
    end
  end

  describe "POST /api/users/:user_id/permissions/:permission_id" do
    test "grants it: the user gains the access at once", ctx do
      assert ctx.as_target |> get(~p"/api/roles") |> response(403)

      conn = post(ctx.as_admin, grant_path(ctx.target, ctx.roles_view), %{notes: "Audit"})

      assert %{
               "user_id" => user_id,
               "permission_id" => permission_id,
               "assigned_by" => assigned_by,
               "notes" => "Audit",
               "inserted_at" => "20" <> _
             } = json_response(conn, 201)["data"]

      assert {user_id, permission_id, assigned_by} ==
               {ctx.target.id, ctx.roles_view.id, ctx.admin.id}

      assert ctx.as_target |> get(~p"/api/roles") |> json_response(200)

      assert %{"permissions" => [%{"slug" => "roles:view"}]} =
               ctx.as_target |> get(~p"/api/me") |> json_response(200) |> get_in(["data", "user"])
    end

    test "a duplicate is a 409, invalid notes a 422", ctx do
      assert json_response(post(ctx.as_admin, grant_path(ctx.target, ctx.roles_view)), 201)

      assert ctx.as_admin |> post(grant_path(ctx.target, ctx.roles_view)) |> error_detail(409) ==
               "Permission already granted to the user"

      conn = post(ctx.as_admin, grant_path(ctx.target, ctx.users_view), %{notes: %{}})
      assert %{"errors" => %{"notes" => [_]}} = json_response(conn, 422)
    end

    test "needs permissions:assign, and holding the permission unless admin",
         %{conn: conn} = ctx do
      assert ctx.as_manager |> post(grant_path(ctx.target, ctx.users_view)) |> error_detail(403) ==
               "Forbidden"

      {_u, token} = create_user_with_token_and(permissions: ["permissions:assign", "roles:view"])
      as_assigner = authenticate_conn(conn, token)

      assert as_assigner |> post(grant_path(ctx.target, ctx.users_view)) |> error_detail(403) ==
               "You can only grant or revoke roles and permissions you hold"

      assert json_response(post(as_assigner, grant_path(ctx.target, ctx.roles_view)), 201)
      refute Authorization.can?(ctx.target, "users:view")
    end

    test "unknown ids are a 404", ctx do
      for id <- invalid_ids() do
        assert ctx.as_admin
               |> post("/api/users/#{id}/permissions/#{ctx.roles_view.id}")
               |> error_detail(404)

        assert ctx.as_admin
               |> post("/api/users/#{ctx.target.id}/permissions/#{id}")
               |> error_detail(404)
      end
    end
  end

  describe "DELETE /api/users/:user_id/permissions/:permission_id" do
    test "revokes it: the user loses the access at once", ctx do
      {:ok, _} = Authorization.assign_permission_to_user(ctx.target, ctx.roles_view)
      assert ctx.as_target |> get(~p"/api/roles") |> json_response(200)

      assert ctx.as_admin |> delete(grant_path(ctx.target, ctx.roles_view)) |> response(204) == ""

      assert ctx.as_target |> get(~p"/api/roles") |> response(403)
      assert %{"direct" => [], "effective" => []} = permissions(ctx.as_admin, ctx.target)

      assert ctx.as_admin |> delete(grant_path(ctx.target, ctx.roles_view)) |> error_detail(404) ==
               "Not Found"
    end

    test "a permission held only through a role is a 409", ctx do
      user = create_user()
      grant_role(user, "manager")

      assert ctx.as_admin |> delete(grant_path(user, ctx.users_view)) |> error_detail(409) =~
               "through a role"

      assert Authorization.can?(user, "users:view")
    end

    test "needs permissions:assign, and holding the permission unless admin",
         %{conn: conn} = ctx do
      {:ok, _} = Authorization.assign_permission_to_user(ctx.target, ctx.users_view)

      assert ctx.as_manager |> delete(grant_path(ctx.target, ctx.users_view)) |> error_detail(403) ==
               "Forbidden"

      {_u, token} = create_user_with_token_and(permissions: ["permissions:assign"])

      assert conn
             |> authenticate_conn(token)
             |> delete(grant_path(ctx.target, ctx.users_view))
             |> error_detail(403) ==
               "You can only grant or revoke roles and permissions you hold"

      assert Authorization.can?(ctx.target, "users:view")
    end

    test "unknown ids are a 404", ctx do
      for id <- invalid_ids() do
        assert ctx.as_admin
               |> delete("/api/users/#{id}/permissions/#{ctx.roles_view.id}")
               |> error_detail(404)

        assert ctx.as_admin
               |> delete("/api/users/#{ctx.target.id}/permissions/#{id}")
               |> error_detail(404)
      end
    end
  end
end
