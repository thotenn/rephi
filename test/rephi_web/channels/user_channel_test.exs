defmodule RephiWeb.UserChannelTest do
  @moduledoc """
  SEC-06 / API-11. Sockets are opened through `UserSocket.connect/3`, the
  same path a real client takes, never built by hand.
  """
  use RephiWeb.ChannelCase, async: true

  import Rephi.AuthTestHelpers

  alias RephiWeb.{Notifications, UserChannel, UserSocket}

  setup do
    {user, token} = create_user_with_token()
    {:ok, socket} = connect(UserSocket, %{}, connect_info: %{auth_token: token})
    %{socket: socket, user: user}
  end

  describe "join" do
    test "any authenticated socket may join user:lobby", %{socket: socket} do
      assert {:ok, _reply, _socket} = subscribe_and_join(socket, UserChannel, "user:lobby")
    end

    test "a user may join its own topic", %{socket: socket, user: user} do
      assert {:ok, _reply, _socket} = subscribe_and_join(socket, UserChannel, "user:#{user.id}")
    end

    test "a user may not join the topic of another user", %{socket: socket} do
      other = create_user()

      assert subscribe_and_join(socket, UserChannel, "user:#{other.id}") ==
               {:error, %{reason: "unauthorized"}}
    end

    test "unknown user:* topics are refused cleanly", %{socket: socket, user: user} do
      for topic <- [
            "user:",
            "user:abc",
            "user:#{user.id}x",
            "user: #{user.id}",
            "user:0#{user.id}"
          ] do
        assert subscribe_and_join(socket, UserChannel, topic) ==
                 {:error, %{reason: "unauthorized"}},
               "joined #{inspect(topic)}"
      end
    end
  end

  describe "client events" do
    setup %{socket: socket} do
      {:ok, _reply, socket} = subscribe_and_join(socket, UserChannel, "user:lobby")
      %{socket: socket}
    end

    test "ping echoes the payload to the sender", %{socket: socket} do
      ref = push(socket, "ping", %{"hello" => "there"})
      assert_reply ref, :ok, %{"hello" => "there"}
    end

    test "shout no longer exists: nothing is broadcast", %{socket: socket} do
      ref = push(socket, "shout", %{"message" => "FAKE ADMIN NOTICE"})

      assert_reply ref, :error, %{reason: "unknown_event"}
      refute_broadcast "shout", _
    end

    test "a client cannot impersonate a server event", %{socket: socket} do
      ref = push(socket, "new_notification", %{"message" => "fake"})

      assert_reply ref, :error, %{reason: "unknown_event"}
      refute_broadcast "new_notification", _
    end

    test "unknown events get an error reply and do not crash the channel", %{socket: socket} do
      Process.flag(:trap_exit, true)

      ref = push(socket, "does_not_exist", %{})
      assert_reply ref, :error, %{reason: "unknown_event"}

      ref = push(socket, "ping", %{})
      assert_reply ref, :ok, %{}
      assert Process.alive?(socket.channel_pid)
    end
  end

  describe "server pushes" do
    test "lobby notifications reach every joined socket", %{socket: socket} do
      {:ok, _reply, _socket} = subscribe_and_join(socket, UserChannel, "user:lobby")
      {:ok, _} = Notifications.broadcast(%{"message" => "Hello everyone"})

      assert_push "new_notification", %{message: "Hello everyone", from: nil}
    end

    test "notify_user/3 reaches only that user's topic", %{socket: socket, user: user} do
      {:ok, _reply, _socket} = subscribe_and_join(socket, UserChannel, "user:#{user.id}")

      {:ok, _} = Notifications.notify_user(create_user(), %{"message" => "Not for you"})
      refute_push "new_notification", _

      {:ok, _} = Notifications.notify_user(user, %{"message" => "Just for you"})
      assert_push "new_notification", %{message: "Just for you"}
    end
  end
end
