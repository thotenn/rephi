defmodule RephiWeb.UserChannelTest do
  @moduledoc "Sockets are opened through `UserSocket.connect/3`, as a real client does."
  use RephiWeb.ChannelCase, async: true

  import Ecto.Query
  import Rephi.AuthTestHelpers

  alias Rephi.Notifications.Notification
  alias Rephi.Repo
  alias RephiWeb.{Notifications, Presence, UserChannel, UserSocket}

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

    test "notify_self/2 reaches only the sender's topic, recorded as self",
         %{socket: socket, user: user} do
      {:ok, _reply, _socket} = subscribe_and_join(socket, UserChannel, "user:lobby")
      {:ok, _reply, _socket} = subscribe_and_join(socket, UserChannel, "user:#{user.id}")
      other = create_user()

      {:ok, _} = Notifications.notify_self(other, %{"message" => "Theirs"})
      {:ok, _} = Notifications.notify_self(user, %{"message" => "Mine"})

      assert_receive %Phoenix.Socket.Message{
        topic: topic,
        event: "new_notification",
        payload: %{message: "Mine", from: %{id: user_id}}
      }

      assert {topic, user_id} == {"user:#{user.id}", user.id}
      refute_receive %Phoenix.Socket.Message{event: "new_notification"}

      assert [%Notification{scope: "self", recipient_id: recipient_id}] =
               Repo.all(from n in Notification, where: n.sender_id == ^user.id)

      assert recipient_id == user.id
    end

    test "every send is recorded with its scope", %{user: user} do
      {:ok, _} = Notifications.broadcast(%{"message" => "All"}, user)
      {:ok, _} = Notifications.notify_user(user.id, %{"message" => "One"})
      {:error, _} = Notifications.broadcast(%{"message" => " "}, user)

      assert [{"broadcast", nil, sender_id}, {"direct", recipient_id, nil}] =
               Repo.all(
                 from n in Notification,
                   order_by: n.id,
                   select: {n.scope, n.recipient_id, n.sender_id}
               )

      assert {sender_id, recipient_id} == {user.id, user.id}
    end
  end

  describe "presence on the lobby" do
    test "a joined socket is tracked under its user id and gets the presence state",
         %{socket: socket, user: user} do
      key = Integer.to_string(user.id)
      {:ok, _reply, lobby} = subscribe_and_join(socket, UserChannel, "user:lobby")

      assert_push "presence_state", state
      assert %{metas: [meta]} = state[key]
      assert %{user_id: user_id, joined_at: joined_at} = meta
      assert user_id == user.id
      assert {:ok, _, 0} = DateTime.from_iso8601(joined_at)

      assert meta |> Map.delete(:phx_ref) |> Map.keys() |> Enum.sort() == [:joined_at, :user_id]

      assert Map.has_key?(Presence.list("user:lobby"), key)

      Process.unlink(lobby.channel_pid)
      ref = leave(lobby)
      assert_reply ref, :ok
      assert_broadcast "presence_diff", %{leaves: %{^key => _}}
    end

    test "the user's private topic is not tracked", %{socket: socket, user: user} do
      {:ok, _reply, _socket} = subscribe_and_join(socket, UserChannel, "user:#{user.id}")

      refute_push "presence_state", _
      refute Map.has_key?(Presence.list("user:#{user.id}"), Integer.to_string(user.id))
    end
  end
end
