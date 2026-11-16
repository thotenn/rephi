defmodule RephiWeb.UserSocketTest do
  @moduledoc """
  Socket authentication (SEC-06, SEC-09, SEC-16), always through
  `UserSocket.connect/3`.
  """
  use RephiWeb.ChannelCase, async: true

  import Rephi.AuthTestHelpers

  alias Rephi.Accounts
  alias RephiWeb.Auth.Guardian
  alias RephiWeb.UserSocket

  setup do
    {user, token} = create_user_with_token()
    %{user: user, token: token}
  end

  defp connect_with_auth_token(token),
    do: connect(UserSocket, %{}, connect_info: %{auth_token: token})

  defp connect_with_param(token), do: connect(UserSocket, %{"token" => token})

  describe "connect/3 with a valid token" do
    test "through the authToken mechanism (connect_info :auth_token)", %{user: user, token: token} do
      assert {:ok, socket} = connect_with_auth_token(token)
      assert socket.assigns.user_id == user.id
    end

    test "through the legacy token param", %{user: user, token: token} do
      assert {:ok, socket} = connect_with_param(token)
      assert socket.assigns.user_id == user.id
    end

    test "authToken wins over the param", %{user: user, token: token} do
      assert {:ok, socket} =
               connect(UserSocket, %{"token" => "garbage"}, connect_info: %{auth_token: token})

      assert socket.assigns.user_id == user.id

      assert :error =
               connect(UserSocket, %{"token" => token}, connect_info: %{auth_token: "garbage"})
    end
  end

  describe "connect/3 refuses" do
    test "no token at all" do
      assert :error = connect(UserSocket, %{})
    end

    test "a token that is not a non-empty string" do
      for token <- [nil, "", 123, %{"a" => 1}, ["x"]] do
        assert :error = connect_with_param(token), "accepted #{inspect(token)}"
      end
    end

    test "a malformed token" do
      assert :error = connect_with_param("invalid_token")
      assert :error = connect_with_auth_token("invalid_token")
    end

    test "an expired token", %{user: user} do
      token = forge_token(user, %{"exp" => System.system_time(:second) - 60})
      assert :error = connect_with_auth_token(token)
      assert :error = connect_with_param(token)
    end

    test "a token that is not an access token", %{user: user} do
      assert :error = connect_with_auth_token(forge_token(user, %{"typ" => "refresh"}))
    end

    test "a token without exp, sub or with a foreign issuer", %{user: user} do
      for claims <- [%{"exp" => nil}, %{"sub" => nil}, %{"iss" => "other-app"}] do
        assert :error = connect_with_auth_token(forge_token(user, claims)),
               "accepted #{inspect(claims)}"
      end
    end

    test "a revoked token", %{user: user, token: token} do
      {:ok, _} = Accounts.revoke_tokens(user)
      assert :error = connect_with_auth_token(token)
    end

    test "the token of a deleted user", %{user: user, token: token} do
      {:ok, _} = Accounts.delete_user(user)
      assert :error = connect_with_auth_token(token)
    end
  end

  describe "id/1" do
    test "is shared by every socket of the user", %{user: user, token: token} do
      {:ok, socket} = connect_with_auth_token(token)
      {:ok, other_token, _claims} = Guardian.encode_and_sign(user)
      {:ok, other_socket} = connect_with_param(other_token)

      assert UserSocket.id(socket) == "user_socket:#{user.id}"
      assert UserSocket.id(other_socket) == UserSocket.id(socket)
      assert UserSocket.id(socket) == Accounts.socket_id(user)
    end

    test "is the topic the disconnect is broadcast on", %{user: user, token: token} do
      {:ok, socket} = connect_with_auth_token(token)
      RephiWeb.Endpoint.subscribe(UserSocket.id(socket))

      {:ok, _} = Accounts.revoke_tokens(user)

      topic = UserSocket.id(socket)
      assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "disconnect"}
    end
  end
end
