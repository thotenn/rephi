defmodule RephiWeb.ApiSpec.Operations do
  @moduledoc """
  Helpers for the `operation` of each controller action (`OpenApiSpex.ControllerSpecs`).
  Example in CLAUDE.md, "Documenting an endpoint".
  """

  alias OpenApiSpex.{Header, Response, Schema}
  alias Plug.Conn.Status
  alias RephiWeb.Schemas

  @json "application/json"
  @password_gate "the caller's password was reset by an administrator and must be changed first with PUT /api/me/password"

  @doc "Needs an access token; pair it with `:unauthorized` in `responses/1`."
  def bearer_auth, do: [%{"bearerAuth" => []}]

  @doc "A record id in the path (anything that is not an existing id answers 404)."
  def id_param(name, description) when is_atom(name) do
    {name,
     [
       in: :path,
       required: true,
       description: description,
       schema: %Schema{type: :integer, minimum: 1}
     ]}
  end

  @doc "`page` and `page_size`; pair them with `:invalid_page` in `responses/1`."
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

  @doc "A JSON request body, required unless `required: false`."
  def body(description, schema, opts \\ []) do
    {description, @json, schema, Keyword.merge([required: true], opts)}
  end

  @doc """
  Responses by status. Bare atoms are standard ones (`:unauthorized`, `:body_errors`,
  `:invalid_page`, `:too_many_requests`, `:password_settled`); an error is just its description.
  """
  def responses(entries) when is_list(entries) do
    {standard, own} = Enum.split_with(entries, &is_atom/1)
    {gate, standard} = Enum.split_with(standard, &(&1 == :password_settled))
    own = if gate == [], do: own, else: with_password_gate(own)

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

  # The gate shares 403 with the permission checks, so it joins their description.
  defp with_password_gate(own) do
    case Keyword.fetch(own, :forbidden) do
      {:ok, description} when is_binary(description) ->
        Keyword.put(own, :forbidden, "#{description}; or #{@password_gate}")

      :error ->
        own ++ [forbidden: "Forbidden - " <> @password_gate]
    end
  end

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
