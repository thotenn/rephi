defmodule RephiWeb.UserSocket do
  @moduledoc """
  The WebSocket of authenticated users, mounted at `/socket`.

  ## Authentication

  A connection needs the same access token the HTTP API uses. It can be sent
  in two ways:

    * **`authToken`** (preferred) - the option of the Phoenix JS client,
      `new Socket("/socket", {authToken: token})`. The token travels in the
      `Sec-WebSocket-Protocol` header and reaches `connect/3` as the
      `:auth_token` connect info, so it never appears in a URL (and therefore
      not in access logs or browser history).
    * **`token` param** (legacy) - `new Socket("/socket", {params: {token}})`,
      which puts the token in the query string. Still accepted so existing
      clients keep working.

  When both are present the `authToken` wins. A missing, malformed, expired or
  revoked token, or a token of a user that no longer exists, refuses the
  connection.

  ## Disconnecting a user

  Every socket of a user shares the id `Rephi.Accounts.socket_id/1`. The
  accounts context broadcasts `"disconnect"` on it when the user logs out,
  changes password or is deleted, which closes all of them.
  """
  use Phoenix.Socket

  alias Rephi.Accounts
  alias RephiWeb.Auth.Guardian

  ## Channels

  channel "user:*", RephiWeb.UserChannel

  @impl true
  def connect(params, socket, connect_info) do
    with token when is_binary(token) <- connect_info[:auth_token] || params["token"],
         {:ok, user, _claims} <- Guardian.resource_from_token(token, %{"typ" => "access"}) do
      {:ok, assign(socket, :user_id, user.id)}
    else
      _ -> :error
    end
  end

  @impl true
  def id(socket), do: Accounts.socket_id(socket.assigns.user_id)
end
