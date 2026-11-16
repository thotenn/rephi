defmodule RephiWeb.Notifications do
  @moduledoc """
  Real-time notifications pushed over `RephiWeb.UserChannel` (`"user:lobby"` for
  everyone, `"user:<id>"` per user) as `"new_notification"` events, each recorded
  with `Rephi.Notifications` first. `message` is plain text: render it as text.
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

  @type result :: {:ok, notification()} | {:error, Ecto.Changeset.t()}

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
  Sends a notification to every connected client (scope `"broadcast"`).

  `attrs` are untrusted: `"message"` must be a non-blank string within the length
  limit, or nothing is recorded nor sent. `sender` is the user, or `nil`.
  """
  @spec broadcast(map(), %User{} | nil) :: result()
  def broadcast(attrs, sender \\ nil) do
    deliver(@lobby, attrs, sender, %{scope: "broadcast"})
  end

  @doc """
  Sends a notification from `user` to the connections of `user` only (scope `"self"`).
  Same validation and return values as `broadcast/2`.
  """
  @spec notify_self(%User{}, map()) :: result()
  def notify_self(%User{} = user, attrs) do
    deliver(user_topic(user), attrs, user, %{scope: "self", recipient_id: user.id})
  end

  @doc """
  Sends a notification to the connections of a single user (scope `"direct"`).
  Same validation and return values as `broadcast/2`.
  """
  @spec notify_user(%User{} | integer(), map(), %User{} | nil) :: result()
  def notify_user(user_or_id, attrs, sender \\ nil) do
    recipient_id = with %User{id: id} <- user_or_id, do: id

    user_or_id
    |> user_topic()
    |> deliver(attrs, sender, %{scope: "direct", recipient_id: recipient_id})
  end

  defp deliver(topic, attrs, sender, record) do
    with {:ok, %{message: message}} <- validate(attrs),
         {:ok, recorded} <-
           record
           |> Map.merge(%{message: message, sender_id: sender && sender.id})
           |> Rephi.Notifications.record() do
      notification = %{
        message: recorded.message,
        type: "general",
        timestamp: recorded.inserted_at,
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
