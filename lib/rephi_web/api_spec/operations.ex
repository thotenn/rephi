defmodule RephiWeb.ApiSpec.Operations do
  @moduledoc """
  Helpers to keep the `operation` of each controller action short.

  A controller documents its actions with `OpenApiSpex.ControllerSpecs`:

      use OpenApiSpex.ControllerSpecs
      import RephiWeb.ApiSpec.Operations
      alias RephiWeb.Schemas

      tags ["Things"]

      operation :archive,
        summary: "Archive a thing",
        description: "Requires things:archive.",
        security: bearer_auth(),
        parameters: [id_param(:id, "Thing ID")],
        request_body: body("Optional notes", Schemas.AssignmentNotes, required: false),
        responses:
          responses([
            :unauthorized,
            :body_errors,
            ok: {"Archived", Schemas.ThingResponse},
            forbidden: "Forbidden - requires things:archive",
            not_found: "Thing not found",
            conflict: "Already archived"
          ])

      def archive(conn, params), do: ...

  `responses/1` knows the envelope of every error status (the project's
  convention, `RephiWeb.FallbackController`), so an error is only its
  description. The operation of the action is read by `RephiWeb.ApiSpec`
  through the router: no list of operations to keep anywhere else.
  """

  alias OpenApiSpex.{Header, Response, Schema}
  alias Plug.Conn.Status
  alias RephiWeb.Schemas

  @json "application/json"

  @doc """
  The operation needs an access token (`Authorization: Bearer <token>`).
  Pair it with `:unauthorized` in `responses/1`.
  """
  def bearer_auth, do: [%{"bearerAuth" => []}]

  @doc """
  A record id in the path. Anything that is not the id of an existing record
  (unknown, not a positive integer, out of range) answers `404`.
  """
  def id_param(name, description) when is_atom(name) do
    {name,
     [
       in: :path,
       required: true,
       description: description,
       schema: %Schema{type: :integer, minimum: 1}
     ]}
  end

  @doc """
  `page` and `page_size` of a paginated list. Pair them with `:invalid_page`
  in `responses/1`.
  """
  def page_params do
    [
      page: [
        in: :query,
        description: "Page, from 1 (default 1)",
        schema: %Schema{type: :integer, minimum: 1}
      ],
      page_size: [
        in: :query,
        description: "Entries per page (default 50; a value over 100 is capped to 100)",
        schema: %Schema{type: :integer, minimum: 1}
      ]
    ]
  end

  @doc """
  A JSON request body. Required unless `required: false`.
  """
  def body(description, schema, opts \\ []) do
    {description, @json, schema, Keyword.merge([required: true], opts)}
  end

  @doc """
  The responses of an operation, keyed by status code.

  `entries` mixes standard responses (bare atoms) and the operation's own
  (`status: value`, the status as a number or a `Plug.Conn.Status` atom).
  An entry of the operation wins over a standard one with the same status.

  Standard responses:

    * `:unauthorized` - `401`, missing, invalid, expired or revoked token
      (every operation with `security: bearer_auth()`);
    * `:body_errors` - `400` malformed JSON and `413` body over 1 MB (every
      operation that reads a body, see `RephiWeb.Plugs.BodyParser`);
    * `:invalid_page` - `422` for an invalid `page` / `page_size`;
    * `:too_many_requests` - `429` with its `retry-after` header
      (`RephiWeb.Plugs.RateLimit`).

  Values of the operation's own entries:

    * `{"description", Schema}` or `{"description", Schema, opts}` - a JSON
      body (`opts`: `headers:`, `example:`);
    * `"description"` - for a `2xx`, a response without a body (`204`); for
      an error, the error envelope: `ValidationErrors` for `422`,
      `ErrorResponse` (plus `retry-after` on `429`) for the rest;
    * an `OpenApiSpex.Response` struct, as is.
  """
  def responses(entries) when is_list(entries) do
    {standard, own} = Enum.split_with(entries, &is_atom/1)

    standard
    |> Enum.flat_map(&standard/1)
    |> Enum.concat(own)
    |> Map.new(fn {status, value} ->
      code = Status.code(status)
      {code, response(code, value)}
    end)
  end

  defp standard(:unauthorized),
    do: [{401, "Missing, invalid, expired or revoked token"}]

  defp standard(:body_errors),
    do: [{400, "Malformed JSON body"}, {413, "Body larger than 1 MB"}]

  defp standard(:invalid_page),
    do: [{422, "page or page_size is not a positive integer"}]

  defp standard(:too_many_requests),
    do: [{429, "Too many attempts from this client; retry after the retry-after header"}]

  defp standard(other),
    do: raise(ArgumentError, "unknown standard response #{inspect(other)}")

  defp response(_code, %Response{} = response), do: response

  defp response(_code, {description, schema}), do: response(nil, {description, schema, []})

  defp response(_code, {description, schema, opts}) when is_binary(description) do
    OpenApiSpex.Operation.response(description, @json, schema, opts)
  end

  defp response(code, description) when is_binary(description) and code < 400 do
    %Response{description: description}
  end

  defp response(422, description) when is_binary(description) do
    OpenApiSpex.Operation.response(description, @json, Schemas.ValidationErrors)
  end

  defp response(429, description) when is_binary(description) do
    OpenApiSpex.Operation.response(description, @json, Schemas.ErrorResponse,
      headers: %{
        "retry-after" => %Header{
          description: "Seconds to wait",
          schema: %Schema{type: :integer}
        }
      }
    )
  end

  defp response(_code, description) when is_binary(description) do
    OpenApiSpex.Operation.response(description, @json, Schemas.ErrorResponse)
  end
end
