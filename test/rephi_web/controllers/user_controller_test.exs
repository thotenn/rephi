defmodule RephiWeb.UserControllerTest do
  @moduledoc "RBAC-06, RBAC-07, RBAC-18 and the user rules of RBAC-04 / RBAC-05."
  use RephiWeb.ConnCase

  alias Rephi.{Accounts, Authorization, Seeds}

  # Seeded: admin -> manager -> user; users:view/edit on manager, users:delete on admin.
  setup %{conn: conn} do
    {:ok, _} = Seeds.run(admin_email: nil, admin_password: nil, admin: :optional)

    {admin, admin_token} = create_user_with_token_and(roles: ["admin"])
    {manager, manager_token} = create_user_with_token_and(roles: ["manager"])
    {plain, plain_token} = create_user_with_token_and(roles: ["user"])

    %{
      conn: conn,
      admin: admin,
      manager: manager,
      plain: plain,
      as_admin: authenticate_conn(conn, admin_token),
      as_manager: authenticate_conn(conn, manager_token),
      as_plain: authenticate_conn(conn, plain_token)
    }
  end

  describe "who may list users (RBAC-07)" do
    test "by permission, not by role", %{conn: conn} = ctx do
      {_u, nobody} = create_user_with_token()
      {_u, direct} = create_user_with_token_and(permissions: ["users:view"])

      for {who, conn, status} <- [
            {"admin", ctx.as_admin, 200},
            {"manager (inherits nothing, holds users:view)", ctx.as_manager, 200},
            {"user role", ctx.as_plain, 403},
            {"no role", authenticate_conn(conn, nobody), 403},
            {"users:view granted directly, no role", authenticate_conn(conn, direct), 200}
          ] do
        assert conn |> get(~p"/api/users") |> response(status), "unexpected status for #{who}"
      end

      assert error_detail(get(conn, ~p"/api/users"), 401) == "Authentication required"
    end

    test "every action needs its own permission", ctx do
      assert ctx.as_manager |> get(~p"/api/users/#{ctx.plain.id}") |> json_response(200)
      assert ctx.as_manager |> get(~p"/api/users/#{ctx.plain.id}/roles") |> json_response(200)

      assert ctx.as_manager
             |> put(~p"/api/users/#{ctx.plain.id}", %{email: "m@example.com"})
             |> json_response(200)

      assert ctx.as_manager |> delete(~p"/api/users/#{ctx.plain.id}") |> error_detail(403) ==
               "Forbidden"

      for {method, path} <- [
            {:get, "/api/users/#{ctx.admin.id}"},
            {:get, "/api/users/#{ctx.admin.id}/roles"},
            {:put, "/api/users/#{ctx.admin.id}"},
            {:delete, "/api/users/#{ctx.admin.id}"}
          ] do
        conn = dispatch(ctx.as_plain, @endpoint, method, path, %{email: "x@example.com"})
        assert error_detail(conn, 403) == "Forbidden", "#{method} #{path}"
      end
    end
  end

  describe "index/2 (RBAC-18)" do
    test "a page of users ordered by id, with meta", %{as_admin: conn} = ctx do
      assert %{"data" => users, "meta" => meta} =
               conn |> get(~p"/api/users") |> json_response(200)

      assert Enum.map(users, & &1["id"]) ==
               Enum.sort([ctx.admin.id, ctx.manager.id, ctx.plain.id])

      assert meta == %{"page" => 1, "page_size" => 50, "total" => 3, "total_pages" => 1}

      admin = Enum.find(users, &(&1["id"] == ctx.admin.id))
      assert [%{"slug" => "admin", "name" => _, "id" => _}] = admin["roles"]
      assert admin["permissions"] == []
      assert admin["inserted_at"] =~ ~r/Z\z/
    end

    test "page and page_size", %{as_admin: conn} = ctx do
      ids = Enum.sort([ctx.admin.id, ctx.manager.id, ctx.plain.id])

      assert %{"data" => [%{"id" => second}], "meta" => meta} =
               conn |> get(~p"/api/users?page=2&page_size=1") |> json_response(200)

      assert second == Enum.at(ids, 1)
      assert meta == %{"page" => 2, "page_size" => 1, "total" => 3, "total_pages" => 3}

      assert %{"data" => [], "meta" => %{"page" => 9}} =
               conn |> get(~p"/api/users?page=9") |> json_response(200)

      assert %{"meta" => %{"page_size" => 100}} =
               conn |> get(~p"/api/users?page_size=5000") |> json_response(200)
    end

    test "an invalid page or page_size is a 422", %{as_admin: conn} do
      for query <- ["page=0", "page=abc", "page_size=0", "page_size=-3", "page=1.5"] do
        assert %{"errors" => errors} = conn |> get("/api/users?#{query}") |> json_response(422)
        assert [field] = Map.keys(errors)
        assert field in ["page", "page_size"], query
      end
    end
  end

  describe "show/2" do
    test "the user with its roles and direct permissions", %{as_admin: conn, plain: plain} do
      assert %{"data" => user} = conn |> get(~p"/api/users/#{plain.id}") |> json_response(200)
      assert user["id"] == plain.id
      assert user["email"] == plain.email
      assert [%{"slug" => "user"}] = user["roles"]
    end

    test "404 for an unknown or invalid id", %{as_admin: conn} do
      for id <- ["99999" | invalid_ids()],
          path <- ["/api/users/#{id}", "/api/users/#{id}/roles"] do
        assert error_detail(get(conn, path), 404) == "Not Found",
               "unexpected response for #{path}"
      end
    end
  end

  describe "update/2 (RBAC-06)" do
    test "only the email is needed, and the password is untouched", ctx do
      conn = put(ctx.as_admin, ~p"/api/users/#{ctx.plain.id}", %{email: "New@Example.com"})

      assert %{"data" => %{"email" => "new@example.com"}} = json_response(conn, 200)
      assert {:ok, _} = Accounts.authenticate_user("new@example.com", "password123")
    end

    test "a password in the body is refused and changes nothing", ctx do
      before = Accounts.get_user(ctx.plain.id)

      for body <- [
            %{email: "x@example.com", password: "a-new-password"},
            %{user: %{password: "a-new-password", password_confirmation: "a-new-password"}}
          ] do
        conn = put(ctx.as_admin, ~p"/api/users/#{ctx.plain.id}", body)

        assert %{"errors" => %{"password" => [message]}} = json_response(conn, 422)
        assert message =~ "PUT /api/me/password"
      end

      after_ = Accounts.get_user(ctx.plain.id)
      assert {after_.email, after_.hashed_password} == {before.email, before.hashed_password}
      assert {:ok, _} = Accounts.authenticate_user(before.email, "password123")
    end

    test "other attributes are ignored", ctx do
      conn =
        put(ctx.as_admin, ~p"/api/users/#{ctx.plain.id}", %{
          email: "ok@example.com",
          token_version: 99,
          hashed_password: "x",
          id: 1
        })

      assert %{"data" => %{"email" => "ok@example.com", "id" => id}} = json_response(conn, 200)
      assert id == ctx.plain.id
      assert Accounts.get_user(ctx.plain.id).token_version == 0
    end

    test "says which field is invalid", %{as_admin: conn, admin: admin, plain: plain} do
      assert conn
             |> put(~p"/api/users/#{plain.id}", %{email: "invalid-email"})
             |> json_response(422) == %{
               "errors" => %{"email" => ["must have the @ sign and no spaces"]}
             }

      assert conn |> put(~p"/api/users/#{plain.id}", %{email: ""}) |> json_response(422) == %{
               "errors" => %{"email" => ["can't be blank"]}
             }

      assert conn
             |> put(~p"/api/users/#{plain.id}", %{email: String.upcase(admin.email)})
             |> json_response(422) == %{"errors" => %{"email" => ["has already been taken"]}}
    end

    test "accepts the attributes wrapped under \"user\"", %{as_admin: conn, plain: plain} do
      conn = patch(conn, ~p"/api/users/#{plain.id}", %{user: %{email: "wrapped@example.com"}})
      assert %{"data" => %{"email" => "wrapped@example.com"}} = json_response(conn, 200)
    end

    test "a user cannot change someone who holds roles it does not (RBAC-05)", ctx do
      conn = put(ctx.as_manager, ~p"/api/users/#{ctx.admin.id}", %{email: "pwned@example.com"})

      assert error_detail(conn, 403) ==
               "You cannot change a user who holds roles you do not hold"

      assert Accounts.get_user(ctx.admin.id).email == ctx.admin.email
    end

    test "404 for an unknown or invalid id", %{as_admin: conn} do
      for id <- ["99999" | invalid_ids()] do
        conn = put(conn, "/api/users/#{id}", %{email: "test@example.com"})
        assert error_detail(conn, 404) == "Not Found", "unexpected response for id #{id}"
      end
    end
  end

  describe "delete/2 (RBAC-04)" do
    test "deletes a user", %{as_admin: conn, plain: plain} do
      assert conn |> delete(~p"/api/users/#{plain.id}") |> response(204) == ""
      assert Accounts.get_user(plain.id) == nil
    end

    test "nobody can delete their own account", %{as_admin: conn, admin: admin} do
      assert conn |> delete(~p"/api/users/#{admin.id}") |> error_detail(409) ==
               "You cannot delete your own account"

      assert Accounts.get_user(admin.id)
    end

    test "a user cannot delete someone who holds roles it does not", ctx do
      {_u, token} = create_user_with_token_and(permissions: ["users:delete"], roles: ["manager"])
      conn = authenticate_conn(ctx.conn, token)

      assert conn |> delete(~p"/api/users/#{ctx.admin.id}") |> error_detail(403) =~
               "roles you do not hold"

      assert conn |> delete(~p"/api/users/#{ctx.plain.id}") |> response(204)
    end

    test "404 for an unknown or invalid id", %{as_admin: conn} do
      for id <- ["99999" | invalid_ids()] do
        assert error_detail(delete(conn, "/api/users/#{id}"), 404) == "Not Found"
      end
    end
  end

  describe "get_user_roles/2" do
    test "the roles assigned to the user, not the inherited ones", ctx do
      assert %{"data" => [%{"name" => "Administrator", "slug" => "admin"} = role]} =
               ctx.as_admin |> get(~p"/api/users/#{ctx.admin.id}/roles") |> json_response(200)

      assert Map.has_key?(role, "description")
      assert Authorization.has_role?(ctx.admin, "user")
    end
  end
end
