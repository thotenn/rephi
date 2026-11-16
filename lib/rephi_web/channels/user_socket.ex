defmodule RephiWeb.UserSocket do
  @moduledoc """
  The WebSocket of authenticated users, at `/socket`. The access token comes as
  `authToken` (in the `Sec-WebSocket-Protocol` header, so never in a URL or log),
  which wins, or as the legacy `token` query param.
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
