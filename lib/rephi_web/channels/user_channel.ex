defmodule RephiWeb.UserChannel do
  @moduledoc """
  Notifications channel: `"user:lobby"` (any authenticated socket, with presence)
  and `"user:<id>"` (only that user). Presence metas reach every lobby member, so
  never put private data in them. Clients may only send `"ping"`.
  """
  use RephiWeb, :channel

  alias RephiWeb.{Notifications, Presence}

  @impl true
  def join("user:lobby", _payload, socket) do
    send(self(), :after_lobby_join)
    {:ok, socket}
  end

  def join("user:" <> _id = topic, _payload, socket) do
    if topic == Notifications.user_topic(socket.assigns.user_id) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info(:after_lobby_join, socket) do
    user_id = socket.assigns.user_id

    {:ok, _ref} =
      Presence.track(socket, Integer.to_string(user_id), %{
        user_id: user_id,
        joined_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
      })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  def handle_in(_event, _payload, socket) do
    {:reply, {:error, %{reason: "unknown_event"}}, socket}
  end
end
