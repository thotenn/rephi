defmodule RephiWeb.DashboardControllerTest do
  use RephiWeb.ConnCase

  import Phoenix.ChannelTest, except: [connect: 2, connect: 3]

  alias Rephi.{Accounts, Notifications}
  alias RephiWeb.{UserChannel, UserSocket}

  defp dashboard(conn, token) do
    conn |> authenticate_conn(token) |> get(~p"/api/dashboard") |> json_response(200)
  end

  defp send_notifications(user) do
    {:ok, _} = RephiWeb.Notifications.broadcast(%{"message" => "All"}, user)
    {:ok, _} = RephiWeb.Notifications.notify_self(user, %{"message" => "Me"})
  end

  test "a plain user sees what it sent and the sessions, not the totals", %{conn: conn} do
    {user, token} = create_user_with_token()
    send_notifications(user)
    send_notifications(create_user())

    assert %{
             "data" => %{
               "users" => %{"total" => nil},
               "notifications" => %{"sent_total" => nil, "sent_by_me" => 2},
               "sessions" => %{"online_users" => online, "connections" => connections}
             }
           } = dashboard(conn, token)

    assert is_integer(online) and connections >= online
  end

  test "users:view shows the number of users", %{conn: conn} do
    {_user, token} = create_user_with_token_and(permissions: ["users:view"])

    assert %{"users" => %{"total" => total}, "notifications" => %{"sent_total" => nil}} =
             dashboard(conn, token)["data"]

    assert total == Accounts.count_users()
  end

  test "notifications:broadcast shows every broadcast", %{conn: conn} do
    {user, token} = create_user_with_token_and(permissions: ["notifications:broadcast"])
    send_notifications(user)
    send_notifications(create_user())

    assert %{
             "users" => %{"total" => nil},
             "notifications" => %{"sent_total" => total, "sent_by_me" => 2}
           } = dashboard(conn, token)["data"]

    assert total == Notifications.count_broadcasts()
    assert total >= 2
  end

  test "sessions count the sockets joined to the lobby", %{conn: conn} do
    {user, token} = create_user_with_token()

    {:ok, socket} =
      Phoenix.ChannelTest.connect(UserSocket, %{}, connect_info: %{auth_token: token})

    {:ok, _reply, _socket} = subscribe_and_join(socket, UserChannel, "user:lobby")
    assert Map.has_key?(RephiWeb.Presence.list("user:lobby"), Integer.to_string(user.id))

    assert %{"online_users" => online, "connections" => connections} =
             dashboard(conn, token)["data"]["sessions"]

    assert online >= 1 and connections >= online
  end

  test "requires authentication", %{conn: conn} do
    assert error_detail(get(conn, ~p"/api/dashboard"), 401) == "Authentication required"
  end

  test "is behind the password gate", %{conn: conn} do
    {:ok, user, _password} = Accounts.reset_password(create_user())
    {:ok, token, _claims} = RephiWeb.Auth.Guardian.encode_and_sign(user)

    conn = conn |> authenticate_conn(token) |> get(~p"/api/dashboard")
    assert error_detail(conn, 403) =~ "Your password was reset"
  end
end
