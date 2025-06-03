defmodule RephiWeb.AuthControllerTest do
  use RephiWeb.ConnCase

  alias Rephi.Accounts
  alias RephiWeb.Auth.Guardian

  @valid_user_attrs %{
    "email" => "test@example.com",
    "password" => "password123"
  }

  @invalid_user_attrs %{
    "email" => "invalid-email",
    "password" => "short"
  }

  describe "register/2" do
    test "creates user and returns token when data is valid", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/users/register", @valid_user_attrs)

      assert %{
               "user" => %{
                 "id" => _id,
                 "email" => "test@example.com"
               },
               "token" => token
             } = json_response(conn, 201)

      assert is_binary(token)
      assert String.length(token) > 0
    end

    test "returns errors when data is invalid", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/users/register", @invalid_user_attrs)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "email")
      assert Map.has_key?(errors, "password")
    end

    test "returns error when email is already taken", %{conn: conn} do
      # Create a user first
      {:ok, _user} = Accounts.create_user(@valid_user_attrs)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/users/register", @valid_user_attrs)

      assert %{"errors" => %{"email" => _}} = json_response(conn, 422)
    end

    test "returns error when required fields are missing", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/users/register", %{})

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "email")
      assert Map.has_key?(errors, "password")
    end
  end

  describe "login/2" do
    setup do
      {:ok, user} = Accounts.create_user(@valid_user_attrs)
      {:ok, user: user}
    end

    test "returns token when credentials are valid", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/users/login", %{
          "email" => @valid_user_attrs["email"],
          "password" => @valid_user_attrs["password"]
        })

      assert %{
               "user" => %{
                 "id" => _id,
                 "email" => "test@example.com"
               },
               "token" => token
             } = json_response(conn, 200)

      assert is_binary(token)
      assert String.length(token) > 0
    end

    test "returns error when email is invalid", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/users/login", %{
          "email" => "wrong@example.com",
          "password" => @valid_user_attrs["password"]
        })

      assert %{"error" => "Invalid email or password"} = json_response(conn, 401)
    end

    test "returns error when password is invalid", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/users/login", %{
          "email" => @valid_user_attrs["email"],
          "password" => "wrongpassword"
        })

      assert %{"error" => "Invalid email or password"} = json_response(conn, 401)
    end

    test "returns error when credentials are missing", %{conn: conn} do
      # Test missing password
      conn1 =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/users/login", %{"email" => "test@example.com"})

      # This will trigger a function clause error, which Phoenix handles as 400 or 500
      assert conn1.status in [400, 500]

      # Test missing email
      conn2 =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/users/login", %{"password" => "password123"})

      assert conn2.status in [400, 500]
    end
  end

  describe "me/2" do
    setup do
      {:ok, user} = Accounts.create_user(@valid_user_attrs)
      {:ok, token, _claims} = Guardian.encode_and_sign(user)
      {:ok, user: user, token: token}
    end

    test "returns current user when authenticated", %{conn: conn, user: user, token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/me")

      assert %{
               "user" => %{
                 "id" => id,
                 "email" => "test@example.com"
               }
             } = json_response(conn, 200)

      assert id == user.id
    end

    test "returns 401 when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/api/me")
      assert json_response(conn, 401)
    end

    test "returns 401 when token is invalid", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid-token")
        |> get(~p"/api/me")

      assert json_response(conn, 401)
    end

    test "returns 401 when authorization header format is wrong", %{conn: conn, token: token} do
      conn =
        conn
        |> put_req_header("authorization", token)
        |> get(~p"/api/me")

      assert json_response(conn, 401)
    end
  end
end
