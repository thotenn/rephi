defmodule RephiWeb.ControllerHelpers do
  @moduledoc """
  Conveniences imported by `use RephiWeb, :controller`.
  """

  alias Plug.Conn

  @doc """
  Returns the write attributes from the request body, flat or wrapped under
  `resource` (`{"role": {...}}`). Path and query parameters are never included.
  """
  @spec resource_params(Conn.t(), String.t()) :: map()
  def resource_params(%Conn{body_params: body_params}, key) when is_binary(key) do
    case body_params do
      %{^key => %{} = wrapped} -> wrapped
      %Conn.Unfetched{} -> %{}
      %{} = flat -> flat
    end
  end

  @doc """
  Maps a unique-constraint error to `{:error, :conflict, message}`, for link
  endpoints where a duplicate means the link already exists. Anything else
  passes through.
  """
  @spec conflict_if_taken(result, String.t()) :: result | {:error, :conflict, String.t()}
        when result: {:ok, term()} | {:error, term()}
  def conflict_if_taken({:error, %Ecto.Changeset{} = changeset} = result, message) do
    if unique_violation?(changeset), do: {:error, :conflict, message}, else: result
  end

  def conflict_if_taken(result, _message), do: result

  defp unique_violation?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn {_field, {_message, opts}} -> opts[:constraint] == :unique end)
  end
end
