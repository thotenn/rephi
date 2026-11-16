defmodule RephiWeb.Auth.TokenValidationTest do
  @moduledoc """
  What the `:authenticated` pipeline accepts as a token. Every rejection is a 401
  in the error envelope, never a 500.
  """
  use RephiWeb.ConnCase, async: true

  alias Rephi.Accounts
  alias RephiWeb.Auth.Guardian

  # Once committed in config/config.exs, so public: tokens signed with it must be rejected.
  @leaked_secret "d3mVezqyv5GuKhoKELh30QdnY3P0u46Y6pIP8DaWVElPvBeahq61pHcey6n4wjhq"

  setup do
    {:ok, user: create_user()}
  end

  defp me(conn, token) do
    conn |> authenticate_conn(token) |> get(~p"/api/me")
  end

  test "a token issued by Guardian is accepted", %{conn: conn, user: user} do
    {:ok, token, _claims} = Guardian.encode_and_sign(user)
    assert %{"data" => %{"user" => %{"id" => id}}} = json_response(me(conn, token), 200)
    assert id == user.id
  end

  test "a forged token with the expected claims is accepted (sanity check of forge_token)",
       %{conn: conn, user: user} do
    assert json_response(me(conn, forge_token(user)), 200)
  end

  test "a token signed with the previously committed secret is rejected",
       %{conn: conn, user: user} do
    token = forge_token(user, %{}, secret: @leaked_secret)
    assert error_detail(me(conn, token), 401) == "Invalid or expired token"
  end

  test "the configured secret is not the previously committed one" do
    refute Application.fetch_env!(:rephi, Guardian)[:secret_key] == @leaked_secret
  end

  describe "malformed or unacceptable claims are a 401" do
    for {name, claims} <- [
          {"typ refresh", %{"typ" => "refresh"}},
          {"no typ", %{"typ" => nil}},
          {"another issuer", %{"iss" => "other-app"}},
          {"no issuer", %{"iss" => nil}},
          {"no exp (a token that never expires)", %{"exp" => nil}},
          {"expired", %{"exp" => System.system_time(:second) - 60}},
          {"no sub", %{"sub" => nil}},
          {"a sub that is not an id", %{"sub" => "abc"}},
          {"a sub out of range", %{"sub" => "99999999999999999999"}},
          {"no token version", %{"ver" => nil}},
          {"a token version that is not an integer", %{"ver" => "0"}}
        ] do
      test name, %{conn: conn, user: user} do
        token = forge_token(user, unquote(Macro.escape(claims)))
        assert error_detail(me(conn, token), 401) == "Invalid or expired token"
      end
    end
  end

  test "the token of a deleted user is a 401 on every authenticated route",
       %{conn: conn, user: user} do
    {:ok, token, _claims} = Guardian.encode_and_sign(user)
    {:ok, _} = Accounts.delete_user(user)

    assert error_detail(me(conn, token), 401) == "Invalid or expired token"

    conn =
      conn
      |> authenticate_conn(token)
      |> post(~p"/api/notifications/broadcast", %{"message" => "still here?"})

    assert error_detail(conn, 401) == "Invalid or expired token"
  end

  describe "revocation (token_version)" do
    test "a password change revokes the tokens issued before it", %{conn: conn, user: user} do
      {:ok, old_token, _claims} = Guardian.encode_and_sign(user)

      {:ok, user} = Accounts.change_password(user, "password123", %{password: "a-new-password"})

      assert user.token_version == 1
      assert error_detail(me(conn, old_token), 401) == "Invalid or expired token"

      {:ok, new_token, _claims} = Guardian.encode_and_sign(user)
      assert json_response(me(conn, new_token), 200)
    end

    test "revoke_tokens/1 revokes every token issued before it", %{conn: conn, user: user} do
      {:ok, first, _claims} = Guardian.encode_and_sign(user)
      {:ok, second, _claims} = Guardian.encode_and_sign(user)

      assert {:ok, %{token_version: 1}} = Accounts.revoke_tokens(user)

      assert error_detail(me(conn, first), 401) == "Invalid or expired token"
      assert error_detail(me(conn, second), 401) == "Invalid or expired token"
    end

    test "revoke_tokens/1 on a deleted user is :not_found", %{user: user} do
      {:ok, _} = Accounts.delete_user(user)
      assert Accounts.revoke_tokens(user) == {:error, :not_found}
    end
  end

  describe "lifetime" do
    test "access tokens last the configured ttl (24 hours by default)", %{user: user} do
      {:ok, _token, claims} = Guardian.encode_and_sign(user)

      assert claims["exp"] - claims["iat"] == 24 * 60 * 60
      assert claims["typ"] == "access"
      assert claims["iss"] == "rephi"
      assert claims["ver"] == 0
    end
  end
end
