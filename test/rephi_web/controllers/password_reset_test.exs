defmodule RephiWeb.PasswordResetTest do
  @moduledoc """
  An administrator resets another user's password
  (`POST /api/users/:id/password`), and the account can then only set a new
  one (`RephiWeb.Auth.PasswordChangeGate`).
  """
  use RephiWeb.ConnCase

  alias Rephi.{Accounts, Authorization, Seeds}

  setup %{conn: conn} do
    {:ok, _} = Seeds.run(admin_email: nil, admin_password: nil, admin: :optional)
    {admin, admin_token} = create_user_with_token_and(roles: ["admin"])
    {manager, manager_token} = create_user_with_token_and(roles: ["manager"])

    %{
      admin: admin,
      manager: manager,
      manager_token: manager_token,
      as_admin: authenticate_conn(conn, admin_token),
      as_manager: authenticate_conn(conn, manager_token)
    }
  end

  defp reset(conn, user), do: post(conn, "/api/users/#{user.id}/password")

  defp login(email, password) do
    build_conn() |> post(~p"/api/users/login", %{email: email, password: password})
  end

  describe "POST /api/users/:id/password" do
    test "returns a temporary password once and ends every session of the user", ctx do
      %{manager: manager} = ctx
      {:ok, other_device, _} = RephiWeb.Auth.Guardian.encode_and_sign(manager)
      RephiWeb.Endpoint.subscribe(Accounts.socket_id(manager))

      conn = reset(ctx.as_admin, manager)

      assert %{"user" => user, "temporary_password" => password} =
               json_response(conn, 200)["data"]

      assert get_resp_header(conn, "cache-control") == ["no-store"]
      assert byte_size(password) == 24

      assert %{"id" => id, "email" => email, "must_change_password" => true} = user
      assert {id, email} == {manager.id, manager.email}
      assert [%{"slug" => "manager"}] = user["roles"]

      # sockets closed, every token revoked
      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect"}

      for revoked <- [ctx.manager_token, other_device] do
        assert build_conn() |> authenticate_conn(revoked) |> get(~p"/api/me") |> error_detail(401) ==
                 "Invalid or expired token"
      end

      # the old password is gone, the temporary one signs in
      assert login(manager.email, "password123") |> error_detail(401)

      assert %{"token" => _, "user" => %{"must_change_password" => true}} =
               login(manager.email, password) |> json_response(200) |> Map.fetch!("data")
    end

    test "the temporary password only lets the user set a new one", %{
      as_admin: conn,
      manager: manager
    } do
      %{"temporary_password" => temporary} =
        conn |> reset(manager) |> json_response(200) |> Map.fetch!("data")

      %{"token" => token} =
        login(manager.email, temporary) |> json_response(200) |> Map.fetch!("data")

      as_reset = authenticate_conn(build_conn(), token)

      # the manager holds users:view and roles:view, but not for now
      for path <- [~p"/api/users", ~p"/api/roles", "/api/users/#{manager.id}/permissions"] do
        assert as_reset |> get(path) |> error_detail(403) ==
                 "Your password was reset: set a new one with PUT /api/me/password before continuing"
      end

      assert %{"must_change_password" => true} =
               as_reset |> get(~p"/api/me") |> json_response(200) |> get_in(["data", "user"])

      # a wrong current password is still a 422
      assert %{"errors" => %{"current_password" => _}} =
               as_reset
               |> put(~p"/api/me/password", %{
                 current_password: "nope",
                 password: "my-own-passphrase"
               })
               |> json_response(422)

      conn =
        put(as_reset, ~p"/api/me/password", %{
          current_password: temporary,
          password: "my-own-passphrase"
        })

      assert %{"token" => new_token, "user" => %{"must_change_password" => false}} =
               json_response(conn, 200)["data"]

      refute Accounts.get_user(manager.id).must_change_password

      assert build_conn()
             |> authenticate_conn(new_token)
             |> get(~p"/api/users")
             |> json_response(200)

      assert login(manager.email, temporary) |> error_detail(401)
    end

    test "a user who must change the password can still log out", %{
      as_admin: conn,
      manager: manager
    } do
      %{"temporary_password" => temporary} =
        conn |> reset(manager) |> json_response(200) |> Map.fetch!("data")

      %{"token" => token} =
        login(manager.email, temporary) |> json_response(200) |> Map.fetch!("data")

      assert build_conn()
             |> authenticate_conn(token)
             |> post(~p"/api/users/logout")
             |> response(204)
    end

    test "your own password is not reset here (409)", %{as_admin: conn, admin: admin} do
      assert conn |> reset(admin) |> error_detail(409) ==
               "You cannot reset your own password; change it with PUT /api/me/password"

      refute Accounts.get_user(admin.id).must_change_password
    end

    test "needs users:reset_password: a manager does not have it", ctx do
      target = create_user()
      grant_role(target, "user")

      assert ctx.as_manager |> reset(target) |> error_detail(403) == "Forbidden"
      refute Accounts.get_user(target.id).must_change_password
    end

    test "a non-admin cannot reset someone holding roles it does not hold", %{conn: conn} = ctx do
      {_u, token} =
        create_user_with_token_and(roles: ["manager"], permissions: ["users:reset_password"])

      as_resetter = authenticate_conn(conn, token)

      assert as_resetter |> reset(ctx.admin) |> error_detail(403) ==
               "You cannot change a user who holds roles you do not hold"

      refute Accounts.get_user(ctx.admin.id).must_change_password

      peer = create_user()
      grant_role(peer, "user")
      assert as_resetter |> reset(peer) |> json_response(200)
    end

    test "unknown ids are a 404", %{as_admin: conn} do
      for id <- invalid_ids() do
        assert conn |> post("/api/users/#{id}/password") |> error_detail(404) == "Not Found"
      end
    end

    test "only the admin role is seeded with the permission" do
      permission = Authorization.get_permission_by_slug("users:reset_password")

      assert for(
               role <- Authorization.list_roles(),
               Authorization.role_has_permission?(role, permission),
               do: role.slug
             ) ==
               ["admin"]
    end
  end
end
