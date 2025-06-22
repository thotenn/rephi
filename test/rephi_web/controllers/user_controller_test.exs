defmodule RephiWeb.UserControllerTest do
  use RephiWeb.ConnCase
  import Rephi.AuthTestHelpers
  alias Rephi.Accounts
  alias Rephi.Authorization

  setup %{conn: conn} do
    # Ensure admin role exists
    admin_role =
      case Authorization.get_role_by_slug("admin") do
        nil ->
          {:ok, role} =
            Authorization.create_role(%{
              name: "Administrator",
              slug: "admin",
              description: "Full system access"
            })

          role

        role ->
          role
      end

    # Create test users with different roles
    admin_user = create_user(%{email: "test_admin@example.com", password: "password123"})
    regular_user = create_user(%{email: "test_user@example.com", password: "password123"})

    # Assign admin role to admin_user
    {:ok, _} = Authorization.assign_role_to_user(admin_user, admin_role)

    # Create tokens
    {:ok, admin_token, _} = RephiWeb.Auth.Guardian.encode_and_sign(admin_user)
    {:ok, user_token, _} = RephiWeb.Auth.Guardian.encode_and_sign(regular_user)

    %{
      conn: conn,
      admin_user: admin_user,
      regular_user: regular_user,
      admin_token: admin_token,
      user_token: user_token
    }
  end

  describe "index/2" do
    test "lists all users when authenticated as admin", %{conn: conn, admin_token: admin_token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{admin_token}")
        |> get(~p"/api/users")

      assert %{"data" => users} = json_response(conn, 200)
      assert is_list(users)
      # Should have at least the admin and regular user we created
      assert length(users) >= 2

      # Verify user structure
      first_user = hd(users)
      assert Map.has_key?(first_user, "id")
      assert Map.has_key?(first_user, "email")
      assert Map.has_key?(first_user, "roles")
      assert Map.has_key?(first_user, "permissions")
    end

    test "returns 403 forbidden when authenticated as regular user", %{
      conn: conn,
      user_token: user_token
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{user_token}")
        |> get(~p"/api/users")

      assert json_response(conn, 403)
    end

    test "returns 401 unauthorized when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/api/users")
      assert json_response(conn, 401)
    end
  end

  describe "show/2" do
    test "shows specific user when authenticated as admin", %{
      conn: conn,
      admin_token: admin_token,
      regular_user: regular_user
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{admin_token}")
        |> get(~p"/api/users/#{regular_user.id}")

      assert %{"data" => user} = json_response(conn, 200)
      assert user["id"] == regular_user.id
      assert user["email"] == regular_user.email
    end

    test "returns 404 when user not found", %{conn: conn, admin_token: admin_token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{admin_token}")
        |> get(~p"/api/users/99999")

      assert json_response(conn, 404)
    end

    test "returns 403 forbidden when authenticated as regular user", %{
      conn: conn,
      user_token: user_token,
      admin_user: admin_user
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{user_token}")
        |> get(~p"/api/users/#{admin_user.id}")

      assert json_response(conn, 403)
    end
  end

  describe "update/2" do
    test "updates user when authenticated as admin", %{
      conn: conn,
      admin_token: admin_token,
      regular_user: regular_user
    } do
      updated_email = "updated_email@example.com"

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{admin_token}")
        |> put(~p"/api/users/#{regular_user.id}", %{
          email: updated_email,
          password: "newpassword123"
        })

      assert %{"data" => user} = json_response(conn, 200)
      assert user["email"] == updated_email

      # Verify the update persisted
      updated_user = Accounts.get_user(regular_user.id)
      assert updated_user.email == updated_email
    end

    test "returns validation errors with invalid data", %{
      conn: conn,
      admin_token: admin_token,
      regular_user: regular_user
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{admin_token}")
        |> put(~p"/api/users/#{regular_user.id}", %{email: "invalid-email", password: "short"})

      assert json_response(conn, 422)
    end

    test "returns 404 when user not found", %{conn: conn, admin_token: admin_token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{admin_token}")
        |> put(~p"/api/users/99999", %{email: "test@example.com"})

      assert json_response(conn, 404)
    end

    test "returns 403 forbidden when authenticated as regular user", %{
      conn: conn,
      user_token: user_token,
      regular_user: regular_user
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{user_token}")
        |> put(~p"/api/users/#{regular_user.id}", %{email: "new@example.com"})

      assert json_response(conn, 403)
    end
  end

  describe "delete/2" do
    test "deletes user when authenticated as admin", %{conn: conn, admin_token: admin_token} do
      # Create a user to delete
      user_to_delete = create_user(%{email: "to_delete@example.com", password: "password123"})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{admin_token}")
        |> delete(~p"/api/users/#{user_to_delete.id}")

      assert response(conn, 204)

      # Verify the user was deleted
      assert Accounts.get_user(user_to_delete.id) == nil
    end

    test "returns 404 when user not found", %{conn: conn, admin_token: admin_token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{admin_token}")
        |> delete(~p"/api/users/99999")

      assert json_response(conn, 404)
    end

    test "returns 403 forbidden when authenticated as regular user", %{
      conn: conn,
      user_token: user_token,
      regular_user: regular_user
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{user_token}")
        |> delete(~p"/api/users/#{regular_user.id}")

      assert json_response(conn, 403)
    end

    test "returns 401 unauthorized when not authenticated", %{
      conn: conn,
      regular_user: regular_user
    } do
      conn = delete(conn, ~p"/api/users/#{regular_user.id}")
      assert json_response(conn, 401)
    end
  end
end
