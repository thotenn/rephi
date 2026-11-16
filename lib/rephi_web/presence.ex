defmodule RephiWeb.Presence do
  @moduledoc """
  Who is connected: every socket joined to `"user:lobby"` is tracked under its user id
  (`RephiWeb.UserChannel`). Lobby members receive `presence_state` / `presence_diff`.
  """
  use Phoenix.Presence,
    otp_app: :rephi,
    pubsub_server: Rephi.PubSub

  @doc "Distinct users and connections present on `topic` (the lobby by default)."
  @spec online_counts(String.t()) :: %{
          online_users: non_neg_integer(),
          connections: non_neg_integer()
        }
  def online_counts(topic \\ RephiWeb.Notifications.lobby_topic()) do
    presences = list(topic)

    %{
      online_users: map_size(presences),
      connections: presences |> Map.values() |> Enum.map(&length(&1.metas)) |> Enum.sum()
    }
  end
end
