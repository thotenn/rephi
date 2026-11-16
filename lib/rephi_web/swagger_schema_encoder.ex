# PhoenixSwagger only returns JSON-ready maps for schemas built with its
# `swagger_schema` DSL. The controllers in this project declare their
# `swagger_definitions/0` as plain maps that embed `PhoenixSwagger.Schema.ref/1`
# structs, so Jason (the JSON library configured for PhoenixSwagger) has to know
# how to encode that struct. `PhoenixSwagger.to_json/1` drops the unset fields,
# which leaves a clean `{"$ref": "#/definitions/..."}` object in swagger.json.
defimpl Jason.Encoder, for: PhoenixSwagger.Schema do
  def encode(schema, opts) do
    schema
    |> PhoenixSwagger.to_json()
    |> Jason.Encode.map(opts)
  end
end
