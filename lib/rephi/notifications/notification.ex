defmodule Rephi.Notifications.Notification do
  @moduledoc """
  A sent notification. `scope` is `"broadcast"` (everybody), `"self"` (a user's test to
  itself) or `"direct"` (one user). Sender and recipient are cleared when deleted.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Rephi.Accounts.User

  @scopes ~w(broadcast self direct)

  schema "notifications" do
    field :message, :string
    field :scope, :string
    belongs_to :sender, User
    belongs_to :recipient, User

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def scopes, do: @scopes

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:message, :scope, :sender_id, :recipient_id])
    |> validate_required([:message, :scope])
    |> validate_inclusion(:scope, @scopes)
    |> validate_recipient()
    |> check_constraint(:scope, name: :notifications_scope_check)
    |> foreign_key_constraint(:sender_id)
    |> foreign_key_constraint(:recipient_id)
  end

  defp validate_recipient(changeset) do
    case get_field(changeset, :scope) do
      "broadcast" ->
        validate_change(changeset, :recipient_id, fn _, _ ->
          [recipient_id: "must be empty for a broadcast"]
        end)

      scope when scope in ["self", "direct"] ->
        validate_required(changeset, [:recipient_id])

      _ ->
        changeset
    end
  end
end
