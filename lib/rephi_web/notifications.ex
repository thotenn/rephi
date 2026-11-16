defmodule RephiWeb.Notifications do
  @moduledoc """
  Real-time notifications pushed to connected clients over `RephiWeb.UserChannel`.

  This is the only place that knows the topics and the shape of the event, so
  HTTP endpoints, background jobs and `iex` all send the same thing.

  ## Topics

    * `"user:lobby"` - every connected client (`broadcast/2`)
    * `"user:<id>"` - the connections of one user (`notify_user/3`)

  ## Event

  Clients receive `"new_notification"` with this payload:

      %{
        message: "Deploy finished",
        type: "general",
        timestamp: ~U[2025-01-01 12:00:00Z],
        from: %{id: 1, email: "admin@example.com"}
      }

  `message` is plain text of at most `max_message_length/0` characters; clients
  must render it as text. `from` is the user that sent it, or `nil` for
  notifications sent by the system.

  ## Configuration

      config :rephi, RephiWeb.Notifications, max_message_length: 500

  """

  import Ecto.Changeset

  alias Rephi.Accounts.User
  alias RephiWeb.Endpoint

  @event "new_notification"
  @lobby "user:lobby"
  @default_max_message_length 500

  @type notification :: %{
          message: String.t(),
          type: String.t(),
          timestamp: DateTime.t(),
          from: %{id: integer(), email: String.t()} | nil
        }

  @doc """
  Topic every authenticated socket may join.
  """
  def lobby_topic, do: @lobby

  @doc """
  Private topic of a user. Only that user may join it.
  """
  def user_topic(%User{id: id}), do: user_topic(id)
  def user_topic(user_id) when is_integer(user_id), do: "user:#{user_id}"

  @doc """
  Longest message accepted, in characters.
  """
  def max_message_length do
    :rephi
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:max_message_length, @default_max_message_length)
  end

  @doc """
  Sends a notification to every connected client.

  `attrs` are untrusted (they usually come from a request body): `"message"`
  must be a non-blank string within the length limit. `sender` is the user
  sending it, or `nil`.

  Returns `{:ok, notification}` or `{:error, changeset}`; nothing is sent when
  the attributes are invalid.
  """
  @spec broadcast(map(), %User{} | nil) :: {:ok, notification()} | {:error, Ecto.Changeset.t()}
  def broadcast(attrs, sender \\ nil) do
    deliver(@lobby, attrs, sender)
  end

  @doc """
  Sends a notification to the connections of a single user.

  Same validation and return values as `broadcast/2`.
  """
  @spec notify_user(%User{} | integer(), map(), %User{} | nil) ::
          {:ok, notification()} | {:error, Ecto.Changeset.t()}
  def notify_user(user_or_id, attrs, sender \\ nil) do
    user_or_id |> user_topic() |> deliver(attrs, sender)
  end

  defp deliver(topic, attrs, sender) do
    with {:ok, %{message: message}} <- validate(attrs) do
      notification = %{
        message: message,
        type: "general",
        timestamp: DateTime.utc_now(),
        from: from(sender)
      }

      Endpoint.broadcast!(topic, @event, notification)
      {:ok, notification}
    end
  end

  defp validate(attrs) do
    {%{}, %{message: :string}}
    |> cast(attrs, [:message])
    |> validate_required([:message])
    |> update_change(:message, &String.trim/1)
    |> validate_length(:message, max: max_message_length())
    |> apply_action(:validate)
  end

  defp from(%User{id: id, email: email}), do: %{id: id, email: email}
  defp from(nil), do: nil
end
