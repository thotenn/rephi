defmodule RephiWeb.AuthControllerTest do
  # One test changes the application environment
  use RephiWeb.ConnCase, async: false

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
               "data" => %{
                 "user" => %{
                   "id" => _id,
                   "email" => "test@example.com",
                   "roles" => [],
                   "permissions" => []
                 },
                 "token" => token
               }
             } = json_response(conn, 201)

      assert is_binary(token)
      assert String.length(token) > 0
    end

    test "accepts the attributes wrapped under \"user\"", %{conn: conn} do
      conn = post(conn, ~p"/api/users/register", %{"user" => @valid_user_attrs})

      assert %{"data" => %{"user" => %{"email" => "test@example.com"}, "token" => _}} =
               json_response(conn, 201)
    end

    test "returns errors when data is invalid", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/users/register", @invalid_user_attrs)

      assert json_response(conn, 422) == %{
               "errors" => %{
                 "email" => ["must have the @ sign and no spaces"],
                 "password" => ["should be at least 8 character(s)"]
               }
             }
    end

    test "returns error when email is already taken", %{conn: conn} do
      # Create a user first
      {:ok, _user} = Accounts.create_user(@valid_user_attrs)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/users/register", @valid_user_attrs)

      assert json_response(conn, 422) == %{"errors" => %{"email" => ["has already been taken"]}}
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
               "data" => %{
                 "user" => %{
                   "id" => _id,
                   "email" => "test@example.com",
                   "roles" => [],
                   "permissions" => []
                 },
                 "token" => token
               }
             } = json_response(conn, 200)

      assert is_binary(token)
      assert String.length(token) > 0
    end

    test "returns the roles and effective permissions of the user", %{conn: conn, user: user} do
      role = grant_role(user, "editor")
      permission = create_permission(%{name: "Edit posts", slug: "posts:edit"})
      {:ok, _} = Rephi.Authorization.assign_permission_to_role(role, permission)

      conn = post(conn, ~p"/api/users/login", @valid_user_attrs)

      assert %{"data" => %{"user" => user_json}} = json_response(conn, 200)
      assert user_json["roles"] == [%{"id" => role.id, "name" => role.name, "slug" => "editor"}]

      assert user_json["permissions"] == [
               %{"id" => permission.id, "name" => "Edit posts", "slug" => "posts:edit"}
             ]
    end

    test "accepts the credentials wrapped under \"user\"", %{conn: conn} do
      conn = post(conn, ~p"/api/users/login", %{"user" => @valid_user_attrs})

      assert %{"data" => %{"token" => _}} = json_response(conn, 200)
    end

    test "returns error when email is invalid", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/users/login", %{
          "email" => "wrong@example.com",
          "password" => @valid_user_attrs["password"]
        })

      assert error_detail(conn, 401) == "Invalid email or password"
    end

    test "returns error when password is invalid", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/users/login", %{
          "email" => @valid_user_attrs["email"],
          "password" => "wrongpassword"
        })

      assert error_detail(conn, 401) == "Invalid email or password"
    end

    test "returns a 400 when credentials are missing or are not strings", %{conn: conn} do
      bodies = [
        %{"email" => "test@example.com"},
        %{"password" => "password123"},
        %{},
        %{"email" => nil, "password" => nil},
        %{"email" => 1, "password" => 2},
        %{"email" => %{"a" => 1}, "password" => ["x"]},
        %{"user" => "not-an-object"}
      ]

      for body <- bodies do
        conn = post(conn, ~p"/api/users/login", body)

        assert error_detail(conn, 400) == "Email and password are required",
               "unexpected response for #{inspect(body)}"
      end
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

      assert json_response(conn, 200) == %{
               "data" => %{
                 "user" => %{
                   "id" => user.id,
                   "email" => "test@example.com",
                   "must_change_password" => false,
                   "roles" => [],
                   "permissions" => []
                 }
               }
             }
    end

    test "returns 401 when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/api/me")
      assert error_detail(conn, 401) == "Authentication required"
    end

    test "returns 401 when token is invalid", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid-token")
        |> get(~p"/api/me")

      assert error_detail(conn, 401) == "Invalid or expired token"
    end

    test "returns 401 when authorization header format is wrong", %{conn: conn, token: token} do
      conn =
        conn
        |> put_req_header("authorization", token)
        |> get(~p"/api/me")

      assert error_detail(conn, 401) == "Authentication required"
    end
  end

  describe "password and email rules on register (SEC-13, SEC-18)" do
    test "7 characters is too short, 8 is enough", %{conn: conn} do
      conn7 =
        post(conn, ~p"/api/users/register", %{
          "email" => "p7@example.com",
          "password" => "1234567"
        })

      assert json_response(conn7, 422) == %{
               "errors" => %{"password" => ["should be at least 8 character(s)"]}
             }

      conn8 =
        post(conn, ~p"/api/users/register", %{
          "email" => "p8@example.com",
          "password" => "12345678"
        })

      assert json_response(conn8, 201)
    end

    test "more than 72 bytes is too long", %{conn: conn} do
      body = %{"email" => "long@example.com", "password" => String.duplicate("€", 25)}

      assert json_response(post(conn, ~p"/api/users/register", body), 422) == %{
               "errors" => %{"password" => ["should be at most 72 byte(s)"]}
             }
    end

    test "an email that differs only in case is taken", %{conn: conn} do
      {:ok, _} = Accounts.create_user(@valid_user_attrs)

      conn =
        post(conn, ~p"/api/users/register", %{@valid_user_attrs | "email" => "Test@Example.com"})

      assert json_response(conn, 422) == %{"errors" => %{"email" => ["has already been taken"]}}
    end

    test "the email is returned normalized and login ignores its case", %{conn: conn} do
      body = %{"email" => " Mixed.Case@Example.com ", "password" => "password123"}

      assert %{"data" => %{"user" => %{"email" => "mixed.case@example.com"}}} =
               json_response(post(conn, ~p"/api/users/register", body), 201)

      login = %{"email" => "MIXED.case@example.com", "password" => "password123"}

      assert %{"data" => %{"token" => _}} =
               json_response(post(conn, ~p"/api/users/login", login), 200)
    end
  end

  describe "logout/2 (SEC-08, SEC-09)" do
    setup do
      {:ok, user} = Accounts.create_user(@valid_user_attrs)
      {:ok, token, _claims} = Guardian.encode_and_sign(user)
      {:ok, user: user, token: token}
    end

    test "revokes every token of the user and disconnects its sockets",
         %{conn: conn, user: user, token: token} do
      {:ok, other_device, _claims} = Guardian.encode_and_sign(user)
      RephiWeb.Endpoint.subscribe(Accounts.socket_id(user))

      conn = conn |> authenticate_conn(token) |> post(~p"/api/users/logout")
      assert response(conn, 204) == ""

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect"}

      for revoked <- [token, other_device] do
        conn = build_conn() |> authenticate_conn(revoked) |> get(~p"/api/me")
        assert error_detail(conn, 401) == "Invalid or expired token"
      end

      conn = post(build_conn(), ~p"/api/users/login", @valid_user_attrs)
      assert %{"data" => %{"token" => new_token}} = json_response(conn, 200)
      assert json_response(build_conn() |> authenticate_conn(new_token) |> get(~p"/api/me"), 200)
    end

    test "logging out twice with the same token is a 401", %{conn: conn, token: token} do
      assert response(conn |> authenticate_conn(token) |> post(~p"/api/users/logout"), 204)

      conn = build_conn() |> authenticate_conn(token) |> post(~p"/api/users/logout")
      assert error_detail(conn, 401) == "Invalid or expired token"
    end

    test "requires a token", %{conn: conn} do
      assert error_detail(post(conn, ~p"/api/users/logout"), 401) == "Authentication required"
    end
  end

  describe "register/2 assigns the default role (RBAC-12)" do
    setup do
      {:ok, _} = Rephi.Seeds.run(admin_email: nil, admin_password: nil, admin: :optional)
      :ok
    end

    test "the new user has the user role, and it shows in the session and /api/me", %{conn: conn} do
      conn = post(conn, ~p"/api/users/register", @valid_user_attrs)

      assert %{
               "data" => %{"user" => %{"roles" => [%{"slug" => "user"}]} = user, "token" => token}
             } =
               json_response(conn, 201)

      assert user["permissions"] == []

      {:ok, claims} = Guardian.decode_and_verify(token)
      assert claims["roles"] == ["user"]

      assert %{"data" => %{"user" => %{"roles" => [%{"slug" => "user"}]}}} =
               build_conn() |> authenticate_conn(token) |> get(~p"/api/me") |> json_response(200)

      assert build_conn() |> authenticate_conn(token) |> get(~p"/api/users") |> response(403)
    end

    test "no role when the default role is disabled", %{conn: conn} do
      put_app_env(Rephi.Accounts, default_role: nil)

      assert %{"data" => %{"user" => %{"roles" => []}}} =
               conn |> post(~p"/api/users/register", @valid_user_attrs) |> json_response(201)
    end

    test "registration works when the default role does not exist", %{conn: conn} do
      put_app_env(Rephi.Accounts, default_role: "missing")

      assert %{"data" => %{"user" => %{"roles" => []}}} =
               conn |> post(~p"/api/users/register", @valid_user_attrs) |> json_response(201)
    end
  end

  describe "change_password/2 (RBAC-06)" do
    setup %{conn: conn} do
      {user, token} = create_user_with_token()
      {:ok, user: user, token: token, as_user: authenticate_conn(conn, token)}
    end

    test "with the current password: new session, old tokens revoked", ctx do
      conn =
        put(ctx.as_user, ~p"/api/me/password", %{
          current_password: "password123",
          password: "a-new-passphrase",
          password_confirmation: "a-new-passphrase"
        })

      assert %{"data" => %{"token" => new_token, "user" => %{"id" => id}}} =
               json_response(conn, 200)

      assert id == ctx.user.id

      assert build_conn() |> authenticate_conn(ctx.token) |> get(~p"/api/me") |> response(401)
      assert build_conn() |> authenticate_conn(new_token) |> get(~p"/api/me") |> response(200)
      assert {:ok, _} = Accounts.authenticate_user(ctx.user.email, "a-new-passphrase")
      assert {:error, _} = Accounts.authenticate_user(ctx.user.email, "password123")
    end

    test "a wrong or missing current password changes nothing", ctx do
      for body <- [
            %{current_password: "wrong-password", password: "a-new-passphrase"},
            %{password: "a-new-passphrase"},
            %{current_password: 123, password: "a-new-passphrase"}
          ] do
        assert ctx.as_user |> put(~p"/api/me/password", body) |> json_response(422) == %{
                 "errors" => %{"current_password" => ["is not valid"]}
               }
      end

      assert {:ok, _} = Accounts.authenticate_user(ctx.user.email, "password123")
      assert ctx.as_user |> get(~p"/api/me") |> response(200)
    end

    test "the new password follows the password rules", ctx do
      conn =
        put(ctx.as_user, ~p"/api/me/password", %{
          user: %{current_password: "password123", password: "short"}
        })

      assert json_response(conn, 422) == %{
               "errors" => %{"password" => ["should be at least 8 character(s)"]}
             }

      conn =
        put(ctx.as_user, ~p"/api/me/password", %{
          current_password: "password123",
          password: "a-new-passphrase",
          password_confirmation: "different"
        })

      assert %{"errors" => %{"password_confirmation" => ["passwords do not match"]}} =
               json_response(conn, 422)
    end

    test "requires a token", %{conn: conn} do
      assert conn |> put(~p"/api/me/password", %{}) |> error_detail(401) ==
               "Authentication required"
    end
  end
end
