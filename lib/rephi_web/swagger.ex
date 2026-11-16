defmodule RephiWeb.Swagger do
  @moduledoc """
  The pieces of the Swagger document every controller shares.

  `mix phx.swagger.generate` builds `priv/static/swagger.json` from the
  `swagger_path` blocks and the `swagger_definitions/0` of the controllers the
  router reaches. This module keeps what they have in common in one place:

    * `definitions/0` - the envelopes (`ErrorResponse`, `ValidationErrors`),
      `PageMeta` and the small summaries of roles and permissions. Every
      controller merges them into its own definitions, so the document has
      them whichever controllers a project keeps.
    * helpers to pipe inside a `swagger_path` block (`import RephiWeb.Swagger`):
      `bearer_auth/1`, `id_param/3`, `page_params/1`, `body_errors/1`,
      `rate_limited/1`, `error_response/3` and `validation_response/2`.
    * `operation_per_verb/1`, for an action served by several verbs (`PUT`
      and `PATCH` of `resources`).

  ## Adding an endpoint

      swagger_path :archive do
        post("/api/things/{id}/archive")
        summary("Archive a thing")
        tag("Things")
        bearer_auth()
        id_param(:id, "Thing ID")
        response(200, "Archived", Schema.ref(:ThingResponse))
        error_response(403, "Forbidden - requires things:archive")
        error_response(404, "Thing not found")
      end

  then `mix phx.swagger.generate`. `test/rephi_web/swagger_contract_test.exs`
  fails until every route of the router is documented and every documented
  response matches what the endpoint answers.
  """

  alias PhoenixSwagger.Path
  alias PhoenixSwagger.Path.PathObject
  alias PhoenixSwagger.Schema

  @doc """
  The operation needs an access token: `Authorization: Bearer <token>`.
  Documents the `401` every authenticated route can answer.
  """
  def bearer_auth(%PathObject{} = path) do
    path
    |> Path.security([%{Bearer: []}])
    |> error_response(401, "Missing, invalid, expired or revoked token")
  end

  @doc """
  A record id in the path. Anything that is not the id of an existing record
  (unknown, not a positive integer, out of range) answers `404`.
  """
  def id_param(%PathObject{} = path, name, description) do
    Path.parameter(path, name, :path, :integer, description, required: true, minimum: 1)
  end

  @doc """
  `page` and `page_size` of a paginated list, and the `422` an invalid value
  answers.
  """
  def page_params(%PathObject{} = path) do
    path
    |> Path.parameter(:page, :query, :integer, "Page, from 1 (default 1)", minimum: 1)
    |> Path.parameter(
      :page_size,
      :query,
      :integer,
      "Entries per page (default 50; a value over 100 is capped to 100)",
      minimum: 1
    )
    |> validation_response("page or page_size is not a positive integer")
  end

  @doc """
  The errors of a request body the endpoint cannot read: malformed JSON
  (`400`) or a body over 1 MB (`413`), see `RephiWeb.Plugs.BodyParser`.
  """
  def body_errors(%PathObject{} = path) do
    path
    |> error_response(400, "Malformed JSON body")
    |> error_response(413, "Body larger than 1 MB")
  end

  @doc """
  The `429` of a rate-limited route (`RephiWeb.Plugs.RateLimit`), with its
  `retry-after` header.
  """
  def rate_limited(%PathObject{} = path) do
    Path.response(
      path,
      429,
      "Too many attempts from this client; retry after the retry-after header",
      Schema.ref(:ErrorResponse),
      headers: %{"retry-after": %{type: :integer, description: "Seconds to wait"}}
    )
  end

  @doc """
  A response with the error envelope: `{"errors": {"detail": "..."}}`.
  """
  def error_response(%PathObject{} = path, status, description) do
    Path.response(path, status, description, Schema.ref(:ErrorResponse))
  end

  @doc """
  A `422` with the validation envelope: `{"errors": {"<field>": ["..."]}}`.
  """
  def validation_response(%PathObject{} = path, description) do
    Path.response(path, 422, description, Schema.ref(:ValidationErrors))
  end

  @doc """
  Gives each verb of a path its own `operationId`.

  A `swagger_path` that leaves the verb and path to the route documents every
  route of the action, and they would all share one `operationId` (the
  document would be invalid). The `PATCH` operation gets `.patch` appended to
  its id; the others keep it. Use it overriding the generated function:

      swagger_path :update do
        ...
      end

      defoverridable swagger_path_update: 1
      def swagger_path_update(route), do: route |> super() |> operation_per_verb()
  """
  def operation_per_verb(paths) when is_map(paths) do
    Map.new(paths, fn {path, operations} ->
      {path, Map.new(operations, fn {verb, operation} -> {verb, suffix(verb, operation)} end)}
    end)
  end

  defp suffix("patch", %{"operationId" => id} = operation),
    do: %{operation | "operationId" => id <> ".patch"}

  defp suffix(_verb, operation), do: operation

  @doc """
  Definitions shared by every controller.
  """
  def definitions do
    %{
      ErrorResponse: %{
        type: :object,
        title: "Error Response",
        description: "Envelope of every error that is not a validation error",
        properties: %{
          errors: %{
            type: :object,
            properties: %{
              detail: %{type: :string, description: "Human readable error message"}
            },
            required: [:detail]
          }
        },
        required: [:errors],
        example: %{errors: %{detail: "Not Found"}}
      },
      ValidationErrors: %{
        type: :object,
        title: "Validation Errors",
        description: "Envelope of a 422: one list of messages per invalid field",
        properties: %{
          errors: %{
            type: :object,
            description: "Validation error messages keyed by field",
            additionalProperties: %{type: :array, items: %{type: :string}}
          }
        },
        required: [:errors],
        example: %{
          errors: %{
            email: ["can't be blank"],
            password: ["should be at least 8 character(s)"]
          }
        }
      },
      PageMeta: %{
        type: :object,
        title: "Page Meta",
        description: "Where a page sits in the whole list",
        properties: %{
          page: %{type: :integer, description: "Current page, from 1"},
          page_size: %{type: :integer, description: "Entries per page (at most 100)"},
          total: %{type: :integer, description: "Entries in the whole list"},
          total_pages: %{type: :integer, description: "Number of pages"}
        },
        required: [:page, :page_size, :total, :total_pages],
        example: %{page: 1, page_size: 50, total: 3, total_pages: 1}
      },
      Grant: %{
        type: :object,
        title: "Grant",
        description: "A role or a permission, by id, name and slug",
        properties: %{
          id: %{type: :integer},
          name: %{type: :string},
          slug: %{type: :string}
        },
        required: [:id, :name, :slug],
        example: %{id: 1, name: "Administrator", slug: "admin"}
      },
      GrantWithDescription: %{
        type: :object,
        title: "Grant With Description",
        description: "A role or a permission with its description",
        properties: %{
          id: %{type: :integer},
          name: %{type: :string},
          slug: %{type: :string},
          description: %{type: :string, "x-nullable": true}
        },
        required: [:id, :name, :slug, :description],
        example: %{id: 5, name: "View Roles", slug: "roles:view", description: "View roles"}
      }
    }
  end

  @doc """
  `definitions/0` plus the ones of a controller.
  """
  def definitions(own) when is_map(own), do: Map.merge(definitions(), own)
end
