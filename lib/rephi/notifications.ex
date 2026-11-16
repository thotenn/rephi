defmodule Rephi.Notifications do
  @moduledoc """
  The record of sent notifications and their counts. Delivery to sockets (topics, payload,
  message validation) is `RephiWeb.Notifications`, which records every send here.
  """

  import Ecto.Query, warn: false
  alias Rephi.Accounts.User
  alias Rephi.Notifications.Notification
  alias Rephi.Repo

  @doc """
  Records a notification. `attrs`: `:message`, `:scope`, `:sender_id`, `:recipient_id`.
  """
  @spec record(map()) :: {:ok, %Notification{}} | {:error, Ecto.Changeset.t()}
  def record(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Broadcasts ever sent, by anyone."
  @spec count_broadcasts() :: non_neg_integer()
  def count_broadcasts do
    Repo.aggregate(from(n in Notification, where: n.scope == "broadcast"), :count)
  end

  @doc "Notifications a user sent, whatever their scope."
  @spec count_sent_by(%User{} | integer()) :: non_neg_integer()
  def count_sent_by(%User{id: id}), do: count_sent_by(id)

  def count_sent_by(user_id) when is_integer(user_id) do
    Repo.aggregate(from(n in Notification, where: n.sender_id == ^user_id), :count)
  end
end
