defmodule RephiWeb.UserChannel do
  @moduledoc """
  Server-to-client channel for notifications.

  ## Topics

    * `"user:lobby"` - any authenticated socket may join. Carries the
      notifications meant for everybody.
    * `"user:<id>"` - only the user with that id may join. Carries the
      notifications meant for that user.

  Any other `user:*` topic is refused with `%{reason: "unauthorized"}`.

  ## Events

  The server pushes `"new_notification"` (see `RephiWeb.Notifications`).

  Clients cannot broadcast: the only event they may send is `"ping"`, whose
  payload is echoed back to the sender alone. Anything else gets an
  `%{reason: "unknown_event"}` error reply instead of crashing the channel.
  To let clients publish something, add a `handle_in/3` clause that validates
  the payload and checks a permission.
  """
  use RephiWeb, :channel

  alias RephiWeb.Notifications

  # Every socket that reaches this point was already authenticated in
  # `RephiWeb.UserSocket.connect/3`.
  @impl true
  def join("user:lobby", _payload, socket) do
    {:ok, socket}
  end

  def join("user:" <> _id = topic, _payload, socket) do
    if topic == Notifications.user_topic(socket.assigns.user_id) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # Liveness check: echoes the payload to the sender only.
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  def handle_in(_event, _payload, socket) do
    {:reply, {:error, %{reason: "unknown_event"}}, socket}
  end
end
