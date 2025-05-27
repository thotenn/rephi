defmodule RephiWeb.UserChannelTest do
  use RephiWeb.ChannelCase
  import Rephi.AuthTestHelpers

  setup do
    # Create a user and token for testing
    {user, token} = create_user_with_token()

    {:ok, _, socket} =
      RephiWeb.UserSocket
      |> socket("user_id", %{token: token})
      |> subscribe_and_join(RephiWeb.UserChannel, "user:lobby")

    %{socket: socket, user: user, token: token}
  end

  test "ping replies with status ok", %{socket: socket} do
    ref = push(socket, "ping", %{"hello" => "there"})
    assert_reply ref, :ok, %{"hello" => "there"}
  end

  test "shout broadcasts to user:lobby", %{socket: socket} do
    push(socket, "shout", %{"hello" => "all"})
    assert_broadcast "shout", %{"hello" => "all"}
  end

  test "broadcasts are pushed to the client", %{socket: socket} do
    broadcast_from!(socket, "broadcast", %{"some" => "data"})
    assert_push "broadcast", %{"some" => "data"}
  end

  test "unauthorized connection is accepted (security issue)" do
    # TODO: This should reject unauthorized connections
    # Currently the WebSocket accepts all connections without validating the token
    assert {:ok, _, _socket} =
             RephiWeb.UserSocket
             |> socket("user_id", %{})
             |> subscribe_and_join(RephiWeb.UserChannel, "user:lobby")
  end

  test "connection with invalid token is accepted (security issue)" do
    # TODO: This should reject connections with invalid tokens
    # Currently the WebSocket accepts all connections without validating the token
    assert {:ok, _, _socket} =
             RephiWeb.UserSocket
             |> socket("user_id", %{token: "invalid-token"})
             |> subscribe_and_join(RephiWeb.UserChannel, "user:lobby")
  end
end
