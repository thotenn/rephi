defmodule RephiWeb.ErrorJSON do
  @moduledoc """
  Renders every non-validation API error as `{"errors": {"detail": "Not Found"}}`,
  for the endpoint (`render_errors`) and `RephiWeb.FallbackController`.
  """

  @doc """
  Renders `"<status>.json"` with the `:detail` assign, or the standard status text.
  """
  def render(template, assigns) do
    %{errors: %{detail: detail(assigns) || status_message(template)}}
  end

  defp detail(%{detail: detail}) when is_binary(detail), do: detail
  defp detail(_assigns), do: nil

  defp status_message(template) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
