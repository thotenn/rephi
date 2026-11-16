defmodule RephiWeb.PermissionControllerTest do
  use RephiWeb.ConnCase

  alias Rephi.Authorization

  @permissions ~w(permissions:view permissions:create permissions:edit permissions:delete
                  permissions:assign)

  setup %{conn: conn} do
    {user, token} = create_user_with_token_and(permissions: @permissions)
    {:ok, conn: authenticate_conn(conn, token), user: user}
  end

  describe "authorization" do
    test "every route answers 401 without a token" do
      for {method, path} <- [
            {:get, "/api/permissions"},
            {:post, "/api/permissions"} | routes(1, 1)
          ] do
        conn = dispatch(build_conn(), @endpoint, method, path)

        assert error_detail(conn, 401) == "Authentication required",
               "unexpected response for #{method} #{path}"
      end
    end

    test "every route answers 403 without the permission" do
      {_user, token} = create_user_with_token()

      for {method, path} <- [
            {:get, "/api/permissions"},
            {:post, "/api/permissions"} | routes(1, 1)
          ] do
        conn = build_conn() |> authenticate_conn(token) |> dispatch(@endpoint, method, path)

        assert error_detail(conn, 403) == "Forbidden",
               "unexpected response for #{method} #{path}"
      end
    end
  end

  describe "index/2 and show/2" do
    test "render permissions", %{conn: conn} do
      permission = create_permission(%{name: "Edit posts", slug: "posts:edit", description: "d"})

      assert %{"data" => permissions} = conn |> get(~p"/api/permissions") |> json_response(200)
      assert Enum.any?(permissions, &(&1["id"] == permission.id))

      assert %{
               "data" => %{
                 "id" => id,
                 "name" => "Edit posts",
                 "slug" => "posts:edit",
                 "description" => "d",
                 "parent_id" => nil,
                 "inserted_at" => _,
                 "updated_at" => _
               }
             } = conn |> get(~p"/api/permissions/#{permission}") |> json_response(200)

      assert id == permission.id
    end
  end

  describe "create/2" do
    test "creates a permission from a flat body", %{conn: conn} do
      conn = post(conn, ~p"/api/permissions", %{name: "Edit posts", slug: "posts:edit"})

      assert %{"data" => %{"id" => id, "slug" => "posts:edit"}} = json_response(conn, 201)
      assert get_resp_header(conn, "location") == ["/api/permissions/#{id}"]
    end

    test "creates a permission from a body wrapped under \"permission\"", %{conn: conn} do
      conn =
        post(conn, ~p"/api/permissions", %{permission: %{name: "Edit posts", slug: "posts:edit"}})

      assert %{"data" => %{"slug" => "posts:edit"}} = json_response(conn, 201)
    end

    test "says which fields are invalid", %{conn: conn} do
      create_permission(%{slug: "posts:edit"})

      assert %{"errors" => %{"name" => ["can't be blank"], "slug" => ["can't be blank"]}} =
               conn |> post(~p"/api/permissions", %{}) |> json_response(422)

      assert %{"errors" => %{"slug" => ["has already been taken"]}} =
               conn
               |> post(~p"/api/permissions", %{name: "x", slug: "posts:edit"})
               |> json_response(422)

      assert %{"errors" => %{"parent_id" => ["does not exist"]}} =
               conn
               |> post(~p"/api/permissions", %{name: "x", slug: "posts:x", parent_id: 999_999})
               |> json_response(422)
    end
  end

  describe "update/2" do
    test "updates a permission from a flat or a wrapped body", %{conn: conn} do
      permission = create_permission()

      assert %{"data" => %{"name" => "Flat"}} =
               conn
               |> put(~p"/api/permissions/#{permission}", %{name: "Flat"})
               |> json_response(200)

      assert %{"data" => %{"name" => "Wrapped"}} =
               conn
               |> patch(~p"/api/permissions/#{permission}", %{permission: %{name: "Wrapped"}})
               |> json_response(200)
    end

    test "says which fields are invalid", %{conn: conn} do
      permission = create_permission()

      conn = put(conn, ~p"/api/permissions/#{permission}", %{name: ""})

      assert json_response(conn, 422) == %{"errors" => %{"name" => ["can't be blank"]}}
    end
  end

  describe "delete/2" do
    test "deletes the permission", %{conn: conn} do
      permission = create_permission()

      assert conn |> delete(~p"/api/permissions/#{permission}") |> response(204) == ""
      assert Authorization.get_permission(permission.id) == nil
    end
  end

  describe "assign_to_role/2" do
    test "returns the assignment that was created", %{conn: conn, user: admin} do
      role = create_role()
      permission = create_permission()

      conn = post(conn, ~p"/api/roles/#{role.id}/permissions/#{permission.id}", %{notes: "Why"})

      assert %{
               "data" => %{
                 "role_id" => role_id,
                 "permission_id" => permission_id,
                 "assigned_by" => assigned_by,
                 "notes" => "Why",
                 "inserted_at" => _
               }
             } = json_response(conn, 201)

      assert {role_id, permission_id, assigned_by} == {role.id, permission.id, admin.id}
      assert Authorization.role_has_permission?(role, permission)
    end

    test "answers 409 when the role already has the permission", %{conn: conn} do
      role = create_role()
      permission = create_permission()
      {:ok, _} = Authorization.assign_permission_to_role(role, permission)

      conn = post(conn, ~p"/api/roles/#{role.id}/permissions/#{permission.id}")

      assert error_detail(conn, 409) == "Permission already assigned to role"
    end
  end

  describe "remove_from_role/2" do
    test "removes the permission and answers 404 once it is gone", %{conn: conn} do
      role = create_role()
      permission = create_permission()
      {:ok, _} = Authorization.assign_permission_to_role(role, permission)

      path = ~p"/api/roles/#{role.id}/permissions/#{permission.id}"

      assert conn |> delete(path) |> response(204) == ""
      refute Authorization.role_has_permission?(role, permission)
      assert conn |> delete(path) |> error_detail(404) == "Not Found"
    end
  end

  describe "ids" do
    test "an unknown or invalid id is a 404 on every route", %{conn: conn} do
      role = create_role()
      permission = create_permission()

      for id <- ["999999" | invalid_ids()],
          {method, path} <- routes(id, id) ++ routes(role.id, id) ++ routes(id, permission.id),
          String.contains?(path, "/#{id}") do
        conn = dispatch(conn, @endpoint, method, path, %{name: "x"})

        assert error_detail(conn, 404) == "Not Found",
               "unexpected response for #{method} #{path}"
      end
    end
  end

  # Every route of the controller that takes an id, for a role and a permission.
  defp routes(role_id, permission_id) do
    [
      {:get, "/api/permissions/#{permission_id}"},
      {:put, "/api/permissions/#{permission_id}"},
      {:patch, "/api/permissions/#{permission_id}"},
      {:delete, "/api/permissions/#{permission_id}"},
      {:post, "/api/roles/#{role_id}/permissions/#{permission_id}"},
      {:delete, "/api/roles/#{role_id}/permissions/#{permission_id}"}
    ]
  end
end
