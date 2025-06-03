defmodule RephiWeb.UserSocketTest do
  use RephiWeb.ChannelCase
  import Rephi.AuthTestHelpers

  alias RephiWeb.UserSocket

  describe "connect/3" do
    test "socket authentication with valid token" do
      user = create_user()
      {:ok, token, _claims} = RephiWeb.Auth.Guardian.encode_and_sign(user)

      # Connect with valid token
      assert {:ok, socket} = connect(UserSocket, %{"token" => token})
      assert socket.assigns.user_id == user.id
    end

    test "socket authentication with invalid token" do
      # Connect with invalid token
      assert :error = connect(UserSocket, %{"token" => "invalid_token"})
    end

    test "socket authentication with expired token" do
      user = create_user()
      # Create token that expires immediately
      {:ok, token, _claims} = RephiWeb.Auth.Guardian.encode_and_sign(user, %{}, ttl: {0, :second})

      # Wait a moment to ensure token is expired
      Process.sleep(100)

      # Connect with expired token
      assert :error = connect(UserSocket, %{"token" => token})
    end

    test "socket authentication without token" do
      # Connect without token parameter
      assert :error = connect(UserSocket, %{})
    end

    test "socket authentication with nil token" do
      # Connect with nil token
      assert :error = connect(UserSocket, %{"token" => nil})
    end

    test "socket authentication with empty token" do
      # Connect with empty token
      assert :error = connect(UserSocket, %{"token" => ""})
    end
  end

  describe "id/1" do
    test "socket id is based on user_id" do
      user = create_user()
      {:ok, token, _claims} = RephiWeb.Auth.Guardian.encode_and_sign(user)

      {:ok, socket} = connect(UserSocket, %{"token" => token})
      assert UserSocket.id(socket) == "user_socket:#{user.id}"
    end
  end
end
