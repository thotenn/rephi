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
      conn =
        post(conn, ~p"/api/notifications/broadcast", %{
          "message" => "Test notification message"
        })

      assert json_response(conn, 200) == %{
               "message" => "Notification sent successfully",
               "notification" => %{
                 "message" => "Test notification message",
                 "timestamp" => json_response(conn, 200)["notification"]["timestamp"]
               }
             }
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

      assert json_response(conn, 401) == %{
               "error" => "unauthenticated"
             }
    end
  end
end
