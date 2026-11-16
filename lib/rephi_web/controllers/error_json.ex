defmodule RephiWeb.ErrorJSON do
  @moduledoc """
  Renders the body of every non-validation error of the API.

  All errors share one envelope:

      {"errors": {"detail": "Not Found"}}

  Validation errors use the same `errors` key with one entry per field and are
  rendered by `RephiWeb.ChangesetJSON`.

  This module is invoked in two ways:

    * by the endpoint (`render_errors` in `config/config.exs`) when a request
      raises: unknown route, malformed JSON body, unhandled exception…
    * by `RephiWeb.FallbackController`, which passes an optional `:detail`
      assign with a message more specific than the HTTP status text.
  """

  @doc """
  Renders `"<status>.json"`.

  Uses the `:detail` assign when it is a string and falls back to the standard
  status message otherwise, so `"404.json"` becomes `"Not Found"`.
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
