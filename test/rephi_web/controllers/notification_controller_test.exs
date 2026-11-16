defmodule RephiWeb.NotificationControllerTest do
  use RephiWeb.ConnCase
  import Rephi.AuthTestHelpers

  describe "broadcast/2" do
    setup %{conn: conn} do
      {user, token} = create_user_with_token()
      conn = authenticate_conn(conn, token)
      {:ok, conn: conn, user: user}
    end

    test "broadcasts notification with valid message", %{conn: conn} do
      RephiWeb.Endpoint.subscribe("user:lobby")

      conn =
        post(conn, ~p"/api/notifications/broadcast", %{
          "message" => "Test notification message"
        })

      assert %{
               "data" => %{
                 "message" => "Test notification message",
                 "timestamp" => timestamp,
                 "type" => "general"
               }
             } = json_response(conn, 200)

      assert {:ok, _datetime, 0} = DateTime.from_iso8601(timestamp)

      assert_receive %Phoenix.Socket.Broadcast{
        topic: "user:lobby",
        event: "new_notification",
        payload: %{message: "Test notification message", type: "general"}
      }
    end

    test "accepts the attributes wrapped under \"notification\"", %{conn: conn} do
      conn =
        post(conn, ~p"/api/notifications/broadcast", %{"notification" => %{"message" => "Hi"}})

      assert %{"data" => %{"message" => "Hi"}} = json_response(conn, 200)
    end

    test "returns error when message is missing", %{conn: conn} do
      conn = post(conn, ~p"/api/notifications/broadcast", %{})

      assert json_response(conn, 422) == %{
               "errors" => %{
                 "message" => ["can't be blank"]
               }
             }
    end

    test "returns error when message is empty", %{conn: conn} do
      conn =
        post(conn, ~p"/api/notifications/broadcast", %{
          "message" => ""
        })

      assert json_response(conn, 422) == %{
               "errors" => %{
                 "message" => ["can't be blank"]
               }
             }
    end

    test "requires authentication", %{conn: _conn} do
      # Create a new connection without authentication
      conn = build_conn()

      conn =
        post(conn, ~p"/api/notifications/broadcast", %{
          "message" => "Test notification"
        })

      assert error_detail(conn, 401) == "Authentication required"
    end
  end
end
