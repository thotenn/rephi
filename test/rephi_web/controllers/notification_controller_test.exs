defmodule RephiWeb.NotificationControllerTest do
  use RephiWeb.ConnCase

  import Ecto.Query
  import Phoenix.ChannelTest, except: [connect: 2, connect: 3]

  alias Rephi.Accounts
  alias Rephi.Notifications.Notification
  alias Rephi.Repo
  alias RephiWeb.Plugs.RateLimit
  alias RephiWeb.{RateLimiter, UserChannel, UserSocket}

  describe "broadcast/2 with the notifications:broadcast permission" do
    setup %{conn: conn} do
      {user, token} = create_user_with_token_and(permissions: ["notifications:broadcast"])
      RephiWeb.Endpoint.subscribe("user:lobby")
      {:ok, conn: authenticate_conn(conn, token), user: user}
    end

    test "broadcasts the message with its sender", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/api/notifications/broadcast", %{"message" => "Test notification message"})

      assert %{
               "data" => %{
                 "message" => "Test notification message",
                 "timestamp" => timestamp,
                 "type" => "general",
                 "from" => %{"id" => user_id, "email" => email}
               }
             } = json_response(conn, 200)

      assert {user_id, email} == {user.id, user.email}
      assert {:ok, _datetime, 0} = DateTime.from_iso8601(timestamp)

      assert_receive %Phoenix.Socket.Broadcast{
        topic: "user:lobby",
        event: "new_notification",
        payload: %{
          message: "Test notification message",
          type: "general",
          from: %{id: ^user_id, email: ^email}
        }
      }
    end

    test "records the broadcast with its sender", %{conn: conn, user: user} do
      post(conn, ~p"/api/notifications/broadcast", %{"message" => "Kept"})

      assert [%Notification{scope: "broadcast", message: "Kept", recipient_id: nil}] =
               Repo.all(from n in Notification, where: n.sender_id == ^user.id)
    end

    test "accepts the attributes wrapped under \"notification\"", %{conn: conn} do
      conn =
        post(conn, ~p"/api/notifications/broadcast", %{"notification" => %{"message" => "Hi"}})

      assert %{"data" => %{"message" => "Hi"}} = json_response(conn, 200)
    end

    test "trims the message", %{conn: conn} do
      conn = post(conn, ~p"/api/notifications/broadcast", %{"message" => "  Hi  "})
      assert %{"data" => %{"message" => "Hi"}} = json_response(conn, 200)
    end

    test "accepts a message of exactly the maximum length", %{conn: conn} do
      message = String.duplicate("a", RephiWeb.Notifications.max_message_length())
      conn = post(conn, ~p"/api/notifications/broadcast", %{"message" => message})
      assert %{"data" => %{"message" => ^message}} = json_response(conn, 200)
    end

    for {name, body, errors} <- [
          {"missing", %{}, ["can't be blank"]},
          {"empty", %{"message" => ""}, ["can't be blank"]},
          {"only whitespace", %{"message" => "   "}, ["can't be blank"]},
          {"a number", %{"message" => 123}, ["is invalid"]},
          {"an object", %{"message" => %{"html" => "<b>x</b>"}}, ["is invalid"]},
          {"a list", %{"message" => ["a", "b"]}, ["is invalid"]},
          {"too long", %{"message" => String.duplicate("a", 501)},
           ["should be at most 500 character(s)"]}
        ] do
      test "rejects a message that is #{name}", %{conn: conn} do
        conn = post(conn, ~p"/api/notifications/broadcast", unquote(Macro.escape(body)))

        assert json_response(conn, 422) == %{"errors" => %{"message" => unquote(errors)}}
        refute_receive %Phoenix.Socket.Broadcast{event: "new_notification"}
      end
    end
  end

  describe "broadcast/2 authorization (SEC-05)" do
    test "a user without the permission gets a 403 and nothing is sent", %{conn: conn} do
      RephiWeb.Endpoint.subscribe("user:lobby")
      {_user, token} = create_user_with_token()

      conn =
        conn
        |> authenticate_conn(token)
        |> post(~p"/api/notifications/broadcast", %{"message" => "spam"})

      assert error_detail(conn, 403) == "Forbidden"
      refute_receive %Phoenix.Socket.Broadcast{event: "new_notification"}
    end

    test "the seeded admin role may broadcast", %{conn: conn} do
      {:ok, _} = Rephi.Seeds.run(admin: :optional, admin_email: nil, admin_password: nil)
      {_user, token} = create_user_with_token_and(roles: ["admin"])

      conn =
        conn
        |> authenticate_conn(token)
        |> post(~p"/api/notifications/broadcast", %{"message" => "Maintenance at 22:00"})

      assert json_response(conn, 200)
    end

    test "the seeded manager and user roles may not", %{conn: conn} do
      {:ok, _} = Rephi.Seeds.run(admin: :optional, admin_email: nil, admin_password: nil)

      for role <- ["manager", "user"] do
        {_user, token} = create_user_with_token_and(roles: [role])

        conn =
          conn
          |> authenticate_conn(token)
          |> post(~p"/api/notifications/broadcast", %{"message" => "Hi"})

        assert error_detail(conn, 403) == "Forbidden"
      end
    end

    test "requires authentication" do
      conn = post(build_conn(), ~p"/api/notifications/broadcast", %{"message" => "Hi"})
      assert error_detail(conn, 401) == "Authentication required"
    end

    test "a deleted user cannot broadcast with its old token", %{conn: conn} do
      {user, token} = create_user_with_token_and(permissions: ["notifications:broadcast"])
      {:ok, _} = Accounts.delete_user(user)

      conn =
        conn
        |> authenticate_conn(token)
        |> post(~p"/api/notifications/broadcast", %{"message" => "Hi"})

      assert error_detail(conn, 401) == "Invalid or expired token"
    end
  end

  describe "notify_self/2" do
    setup %{conn: conn} do
      {user, token} = create_user_with_token()
      {:ok, conn: authenticate_conn(conn, token), user: user, token: token}
    end

    defp join_own_topics(token, user) do
      {:ok, socket} =
        Phoenix.ChannelTest.connect(UserSocket, %{}, connect_info: %{auth_token: token})

      {:ok, _reply, _socket} = subscribe_and_join(socket, UserChannel, "user:lobby")
      {:ok, _reply, _socket} = subscribe_and_join(socket, UserChannel, "user:#{user.id}")
      assert_push "presence_state", _
    end

    test "any signed-in user notifies itself, with the broadcast's payload", %{
      conn: conn,
      user: user,
      token: token
    } do
      join_own_topics(token, user)
      conn = post(conn, ~p"/api/notifications/me", %{"message" => "  Testing  "})

      assert %{
               "data" => %{
                 "message" => "Testing",
                 "type" => "general",
                 "timestamp" => timestamp,
                 "from" => %{"id" => user_id, "email" => email}
               }
             } = json_response(conn, 200)

      assert {user_id, email} == {user.id, user.email}
      assert {:ok, _datetime, 0} = DateTime.from_iso8601(timestamp)

      assert_receive %Phoenix.Socket.Message{
        topic: topic,
        event: "new_notification",
        payload: %{message: "Testing", type: "general", from: %{id: ^user_id, email: ^email}}
      }

      assert topic == "user:#{user.id}"
      refute_receive %Phoenix.Socket.Message{event: "new_notification"}

      assert [%Notification{scope: "self", recipient_id: ^user_id}] =
               Repo.all(from n in Notification, where: n.sender_id == ^user_id)
    end

    test "another user does not receive it, but still gets broadcasts", %{conn: conn} do
      {other, other_token} = create_user_with_token()
      join_own_topics(other_token, other)

      assert json_response(post(conn, ~p"/api/notifications/me", %{"message" => "Private"}), 200)
      refute_receive %Phoenix.Socket.Message{event: "new_notification"}

      {:ok, _} = RephiWeb.Notifications.broadcast(%{"message" => "Public"})

      assert_receive %Phoenix.Socket.Message{
        topic: "user:lobby",
        event: "new_notification",
        payload: %{message: "Public"}
      }
    end

    test "accepts the attributes wrapped under \"notification\"", %{conn: conn} do
      conn = post(conn, ~p"/api/notifications/me", %{"notification" => %{"message" => "Hi"}})
      assert %{"data" => %{"message" => "Hi"}} = json_response(conn, 200)
    end

    for {name, body, errors} <- [
          {"missing", %{}, ["can't be blank"]},
          {"only whitespace", %{"message" => "   "}, ["can't be blank"]},
          {"a number", %{"message" => 123}, ["is invalid"]},
          {"too long", %{"message" => String.duplicate("a", 501)},
           ["should be at most 500 character(s)"]}
        ] do
      test "rejects a message that is #{name} and records nothing", %{conn: conn} do
        conn = post(conn, ~p"/api/notifications/me", unquote(Macro.escape(body)))

        assert json_response(conn, 422) == %{"errors" => %{"message" => unquote(errors)}}
        assert Repo.aggregate(Notification, :count) == 0
      end
    end

    test "requires authentication" do
      conn = post(build_conn(), ~p"/api/notifications/me", %{"message" => "Hi"})
      assert error_detail(conn, 401) == "Authentication required"
    end

    test "is behind the password gate" do
      {:ok, user, _password} = Accounts.reset_password(create_user())
      {:ok, token, _claims} = RephiWeb.Auth.Guardian.encode_and_sign(user)

      conn =
        build_conn()
        |> authenticate_conn(token)
        |> post(~p"/api/notifications/me", %{"message" => "Hi"})

      assert error_detail(conn, 403) =~ "Your password was reset"
    end

    test "is rate limited per user, with retry-after", %{conn: conn} do
      put_app_env(RateLimit, enabled: true, self_notification: [limit: 2, window_seconds: 60])
      RateLimiter.reset()
      on_exit(&RateLimiter.reset/0)

      for _ <- 1..2 do
        assert json_response(post(conn, ~p"/api/notifications/me", %{"message" => "Hi"}), 200)
      end

      limited = post(conn, ~p"/api/notifications/me", %{"message" => "Hi"})
      assert error_detail(limited, 429) =~ "Too many attempts"
      assert [retry_after] = get_resp_header(limited, "retry-after")
      assert String.to_integer(retry_after) in 1..60
      assert Repo.aggregate(Notification, :count) == 2

      {_other, other_token} = create_user_with_token()

      assert build_conn()
             |> authenticate_conn(other_token)
             |> post(~p"/api/notifications/me", %{"message" => "Hi"})
             |> json_response(200)
    end
  end
end
