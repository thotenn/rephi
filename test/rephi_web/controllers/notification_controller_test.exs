defmodule RephiWeb.NotificationControllerTest do
  use RephiWeb.ConnCase

  alias Rephi.Accounts

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
end
