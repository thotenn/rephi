defmodule RephiWeb.NotificationJSON do
  @moduledoc """
  Renders notifications.
  """

  @doc """
  Renders a single notification.
  """
  def show(%{notification: notification}) do
    %{data: Map.take(notification, [:message, :timestamp, :type, :from])}
  end
end
