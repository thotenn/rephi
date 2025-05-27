defmodule RephiWeb.Integration.AuthFlowTest do
  use RephiWeb.ConnCase
  
  @user_attrs %{
    "email" => "integration@example.com",
    "password" => "password123"
  }

  describe "complete authentication flow" do
    test "user can register, login, and access protected endpoints", %{conn: conn} do
      # Step 1: Register a new user
      register_conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/users/register", @user_attrs)

      assert %{
               "user" => %{"id" => user_id, "email" => "integration@example.com"},
               "token" => register_token
             } = json_response(register_conn, 201)

      # Step 2: Verify the token works for protected endpoints
      me_conn =
        conn
        |> put_req_header("authorization", "Bearer #{register_token}")
        |> get(~p"/api/me")

      assert %{
               "user" => %{"id" => ^user_id, "email" => "integration@example.com"}
             } = json_response(me_conn, 200)

      # Step 3: Login with credentials
      login_conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/users/login", @user_attrs)

      assert %{
               "user" => %{"id" => ^user_id, "email" => "integration@example.com"},
               "token" => login_token
             } = json_response(login_conn, 200)

      # Step 4: Verify login token also works
      me_conn2 =
        conn
        |> put_req_header("authorization", "Bearer #{login_token}")
        |> get(~p"/api/me")

      assert %{
               "user" => %{"id" => ^user_id, "email" => "integration@example.com"}
             } = json_response(me_conn2, 200)

      # Both tokens should be different but valid
      assert register_token != login_token
    end

    test "unauthorized access is properly rejected", %{conn: conn} do
      # Try to access protected endpoint without token
      conn1 = get(conn, ~p"/api/me")
      assert json_response(conn1, 401)

      # Try with invalid token
      conn2 =
        conn
        |> put_req_header("authorization", "Bearer invalid-token")
        |> get(~p"/api/me")
      
      assert json_response(conn2, 401)

      # Try with wrong format
      conn3 =
        conn
        |> put_req_header("authorization", "NotBearer some-token")
        |> get(~p"/api/me")
      
      assert json_response(conn3, 401)
    end

    test "multiple users can coexist with separate sessions", %{conn: conn} do
      # Create first user
      user1_attrs = %{"email" => "user1@example.com", "password" => "password123"}
      conn1 =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/users/register", user1_attrs)

      %{"user" => %{"id" => user1_id}, "token" => token1} = json_response(conn1, 201)

      # Create second user
      user2_attrs = %{"email" => "user2@example.com", "password" => "password456"}
      conn2 =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/users/register", user2_attrs)

      %{"user" => %{"id" => user2_id}, "token" => token2} = json_response(conn2, 201)

      # Verify first user's token returns first user's data
      me_conn1 =
        conn
        |> put_req_header("authorization", "Bearer #{token1}")
        |> get(~p"/api/me")

      assert %{"user" => %{"id" => ^user1_id, "email" => "user1@example.com"}} =
               json_response(me_conn1, 200)

      # Verify second user's token returns second user's data
      me_conn2 =
        conn
        |> put_req_header("authorization", "Bearer #{token2}")
        |> get(~p"/api/me")

      assert %{"user" => %{"id" => ^user2_id, "email" => "user2@example.com"}} =
               json_response(me_conn2, 200)

      # Ensure user IDs are different
      assert user1_id != user2_id
    end

    test "login fails after providing wrong credentials", %{conn: conn} do
      # Register user first
      conn
      |> put_req_header("content-type", "application/json")
      |> post(~p"/api/users/register", @user_attrs)

      # Try to login with wrong password
      wrong_pass_conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/users/login", %{
          "email" => @user_attrs["email"],
          "password" => "wrongpassword"
        })

      assert %{"error" => "Invalid email or password"} = json_response(wrong_pass_conn, 401)

      # Try to login with wrong email
      wrong_email_conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/users/login", %{
          "email" => "wrong@example.com",
          "password" => @user_attrs["password"]
        })

      assert %{"error" => "Invalid email or password"} = json_response(wrong_email_conn, 401)
    end
  end

  describe "error handling" do
    test "registration validation errors are properly formatted", %{conn: conn} do
      invalid_attrs = %{
        "email" => "not-an-email",
        "password" => "short"
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/users/register", invalid_attrs)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert is_map(errors)
      assert Map.has_key?(errors, "email")
      assert Map.has_key?(errors, "password")
      assert is_list(errors["email"])
      assert is_list(errors["password"])
    end

    test "duplicate email registration is rejected", %{conn: conn} do
      # Register first user
      conn
      |> put_req_header("content-type", "application/json")
      |> post(~p"/api/users/register", @user_attrs)

      # Try to register again with same email
      duplicate_conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/users/register", @user_attrs)

      assert %{"errors" => %{"email" => email_errors}} = json_response(duplicate_conn, 422)
      assert is_list(email_errors)
    end
  end
end