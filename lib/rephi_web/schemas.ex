defmodule RephiWeb.Schemas do
  @moduledoc """
  The bodies of the API document (`RephiWeb.ApiSpec`), one module per body
  under `RephiWeb.Schemas.*` (`lib/rephi_web/schemas/`).

  Each module is an `OpenApiSpex.schema/2` and becomes a component of the
  document named after its last segment (`RephiWeb.Schemas.Role` ->
  `#/components/schemas/Role`), so the last segment must be unique:

      defmodule RephiWeb.Schemas.Thing do
        require OpenApiSpex
        alias OpenApiSpex.Schema

        OpenApiSpex.schema(
          %{
            type: :object,
            properties: %{
              id: %Schema{type: :integer},
              name: %Schema{type: :string},
              note: %Schema{type: :string, nullable: true}
            },
            required: [:id, :name, :note]
          },
          struct?: false
        )
      end

      defmodule RephiWeb.Schemas.ThingResponse do
        require OpenApiSpex

        OpenApiSpex.schema(
          RephiWeb.Schemas.data(RephiWeb.Schemas.Thing, description: "A single thing"),
          struct?: false
        )
      end

  Conventions, checked by `test/rephi_web/api_contract_test.exs`:

    * a response object lists in `required` every property it declares (the
      views always send every field; a field that can be empty is
      `nullable: true`, never left out);
    * a response sends no field its schema does not declare;
    * `struct?: false`: the schemas only describe JSON, nothing is cast into
      structs.

  The helpers below build the envelopes every response shares.
  """

  alias OpenApiSpex.Schema

  @doc """
  The success envelope: `{"data": <schema>}`.

  `attrs` (a keyword list or map) adds or overrides schema fields
  (`description`, `example`, ...).
  """
  def data(schema, attrs \\ []) do
    Map.merge(
      %{type: :object, properties: %{data: schema}, required: [:data]},
      Map.new(attrs)
    )
  end

  @doc """
  The envelope of a paginated list: `{"data": [<item>], "meta": PageMeta}`.
  """
  def page(item, attrs \\ []) do
    Map.merge(
      %{
        type: :object,
        properties: %{
          data: %Schema{type: :array, items: item},
          meta: RephiWeb.Schemas.PageMeta
        },
        required: [:data, :meta]
      },
      Map.new(attrs)
    )
  end

  @doc """
  A UTC timestamp as the views render it (`2026-01-03T10:00:00Z`).
  """
  def timestamp(attrs \\ []) do
    struct(%Schema{type: :string, format: :"date-time"}, attrs)
  end
end
