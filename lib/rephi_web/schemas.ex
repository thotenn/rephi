defmodule RephiWeb.Schemas do
  @moduledoc """
  Envelope helpers for the `RephiWeb.Schemas.*` body schemas. A response schema lists
  every property in `required`; the component name is the module's last segment.
  """

  alias OpenApiSpex.Schema

  @doc ~S'`{"data": schema}`; `attrs` adds schema fields (`description`, `example`).'
  def data(schema, attrs \\ []) do
    Map.merge(
      %{type: :object, properties: %{data: schema}, required: [:data]},
      Map.new(attrs)
    )
  end

  @doc ~S'`{"data": [item], "meta": PageMeta}`.'
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

  @doc "A date-time string."
  def timestamp(attrs \\ []) do
    struct(%Schema{type: :string, format: :"date-time"}, attrs)
  end
end
