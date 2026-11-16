defmodule RephiWeb.ChangesetJSON do
  @moduledoc """
  Renders validation errors as `{"errors": {"email": ["has already been taken"]}}`,
  translated with the `"errors"` Gettext domain.
  """

  @doc """
  Renders the errors of a changeset.
  """
  def error(%{changeset: changeset}) do
    %{errors: translate_errors(changeset)}
  end

  @doc """
  Returns the errors of a changeset as a map of field to translated messages.
  Never raises: option values that cannot be interpolated are inspected.
  """
  def translate_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
  end

  defp translate_error({msg, opts}) do
    bindings = Map.new(opts, fn {key, value} -> {key, printable(value)} end)

    case opts[:count] do
      count when is_integer(count) and count >= 0 ->
        Gettext.dngettext(RephiWeb.Gettext, "errors", msg, msg, count, bindings)

      _ ->
        Gettext.dgettext(RephiWeb.Gettext, "errors", msg, bindings)
    end
  end

  defp printable(value) when is_binary(value) or is_number(value) or is_atom(value), do: value
  defp printable(value), do: inspect(value)
end
