defmodule RephiWeb.ChangesetJSONTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset

  alias RephiWeb.ChangesetJSON

  defp changeset(types, params) do
    cast({%{}, types}, params, Map.keys(types))
  end

  test "renders one list of messages per invalid field" do
    changeset =
      %{name: :string, slug: :string}
      |> changeset(%{})
      |> validate_required([:name, :slug])

    assert ChangesetJSON.error(%{changeset: changeset}) ==
             %{errors: %{name: ["can't be blank"], slug: ["can't be blank"]}}
  end

  test "interpolates the options used by the message" do
    changeset =
      %{password: :string}
      |> changeset(%{"password" => "abc"})
      |> validate_length(:password, min: 6)

    assert ChangesetJSON.translate_errors(changeset) ==
             %{password: ["should be at least 6 character(s)"]}
  end

  test "does not raise on options that are not printable (API-18)" do
    changeset = changeset(%{tags: {:array, :string}}, %{"tags" => "x"})

    assert [tags: {_message, opts}] = changeset.errors
    assert opts[:type] == {:array, :string}
    assert ChangesetJSON.translate_errors(changeset) == %{tags: ["is invalid"]}
  end

  test "does not raise when the message itself interpolates an unprintable option" do
    changeset =
      %{role: :string}
      |> changeset(%{})
      |> add_error(:role, "must be one of %{allowed} (%{type})",
        allowed: [:admin, :user],
        type: {:array, :string}
      )

    assert ChangesetJSON.translate_errors(changeset) ==
             %{role: ["must be one of [:admin, :user] ({:array, :string})"]}
  end

  test "does not raise when :count is not a number" do
    changeset =
      %{name: :string}
      |> changeset(%{})
      |> add_error(:name, "has %{count} problems", count: "several")

    assert ChangesetJSON.translate_errors(changeset) == %{name: ["has several problems"]}
  end

  test "keeps every message of a field" do
    changeset =
      %{email: :string}
      |> changeset(%{})
      |> validate_required([:email])
      |> add_error(:email, "is reserved")

    assert ChangesetJSON.translate_errors(changeset) ==
             %{email: ["is reserved", "can't be blank"]}
  end
end
