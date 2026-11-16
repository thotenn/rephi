defmodule RephiWeb.ChangesetJSON do
  @moduledoc """
  Renders validation errors in the API error envelope, one entry per field:

      {"errors": {"email": ["has already been taken"]}}

  Messages go through the `"errors"` Gettext domain, so they can be translated
  in `priv/gettext`.
  """

  @doc """
  Renders the errors of a changeset.
  """
  def error(%{changeset: changeset}) do
    %{errors: translate_errors(changeset)}
  end

  @doc """
  Returns the errors of a changeset as a map of field to translated messages.

  Never raises, whatever the error options contain: values that cannot be
  interpolated as text (tuples such as `type: {:array, :string}`, lists of
  atoms…) are inspected instead.
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
