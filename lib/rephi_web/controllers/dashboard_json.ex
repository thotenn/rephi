defmodule RephiWeb.DashboardJSON do
  @moduledoc """
  Renders the dashboard counters.
  """

  def show(%{dashboard: dashboard}), do: %{data: dashboard}
end
