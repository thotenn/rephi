defmodule RephiWeb.HealthJSON do
  @moduledoc """
  Renders the result of a health check.
  """

  @doc """
  Renders a passing health check with the dependencies that were verified.
  """
  def show(%{checks: checks}) when map_size(checks) == 0 do
    %{data: %{status: "ok"}}
  end

  def show(%{checks: checks}) do
    %{data: %{status: "ok", checks: checks}}
  end
end
