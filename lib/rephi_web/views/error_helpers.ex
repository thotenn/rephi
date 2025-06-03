defmodule RephiWeb.ErrorHelpers do
  @moduledoc """
  Conveniences for formatting and returning error responses.
  Provides consistent error formatting across the application.
  """

  import Phoenix.Controller, only: [json: 2]

  @doc """
  Returns a standardized error response with a single error message.
  """
  def render_error(conn, status, message) when is_atom(status) and is_binary(message) do
    conn
    |> put_status(status)
    |> json(%{error: message})
  end

  @doc """
  Returns a standardized error response with multiple error messages.
  """
  def render_errors(conn, status, errors) when is_atom(status) and is_map(errors) do
    conn
    |> put_status(status)
    |> json(%{errors: errors})
  end

  @doc """
  Translates changeset errors to a map.
  """
  def translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  @doc """
  Returns validation errors from a changeset.
  """
  def render_changeset_errors(conn, changeset) do
    errors = translate_errors(changeset)
    render_errors(conn, :unprocessable_entity, errors)
  end

  @doc """
  Returns an unauthorized error response.
  """
  def render_unauthorized(conn, message \\ "Unauthorized") do
    render_error(conn, :unauthorized, message)
  end

  @doc """
  Returns a not found error response.
  """
  def render_not_found(conn, message \\ "Not found") do
    render_error(conn, :not_found, message)
  end

  @doc """
  Returns a bad request error response.
  """
  def render_bad_request(conn, message) do
    render_error(conn, :bad_request, message)
  end

  defp put_status(conn, status) do
    Plug.Conn.put_status(conn, status)
  end
end
