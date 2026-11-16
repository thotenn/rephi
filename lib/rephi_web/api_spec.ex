defmodule RephiWeb.ApiSpec do
  @moduledoc """
  The OpenAPI 3.0 document of the API.

  The paths come from the router: every route whose controller declares an
  `operation` for its action (`OpenApiSpex.ControllerSpecs`, helpers in
  `RephiWeb.ApiSpec.Operations`). The schemas are the `RephiWeb.Schemas.*`
  modules the operations reach. Nothing is generated to disk:

    * `GET /api/openapi` serves it (`RephiWeb.OpenApiController`) and
      `GET /api/swagger` is the Swagger UI on top of it, both only where
      `config :rephi, :swagger_enabled` is true (`SWAGGER_ENABLED`);
    * `mix openapi.spec.json --spec RephiWeb.ApiSpec --start-app=false`
      writes it to a file for a client generator or CI;
    * `test/rephi_web/api_contract_test.exs` checks it against the API.

  The document is built once and cached (`OpenApiSpex.Plug.PutApiSpec`);
  development turns the cache off (`config/dev.exs`) so a changed operation
  shows up after a reload.
  """

  @behaviour OpenApiSpex.OpenApi

  alias OpenApiSpex.{
    Components,
    Info,
    OpenApi,
    Operation,
    PathItem,
    SecurityScheme,
    Server,
    Tag
  }

  @version Mix.Project.config()[:version]

  @description """
  Phoenix JSON API with JWT authentication, role-based access control and \
  real-time notifications over WebSockets (`/socket`, channel `user:lobby`).

  **Envelopes.** A successful response with a body is `{"data": ...}`; a \
  paginated list adds `"meta": {"page", "page_size", "total", "total_pages"}` \
  (`page` from 1, `page_size` 50 by default, at most 100). An error is \
  `{"errors": {"detail": "message"}}`, or `{"errors": {"field": ["message"]}}` \
  for a validation error (422).

  **Status codes.** 400 malformed JSON or missing credentials; 401 missing, \
  invalid, expired or revoked token; 403 missing permission, or granting what \
  the caller does not hold; 404 unknown record or route (also for an id that \
  is not a positive integer); 409 the change conflicts with the data (system \
  records, last admin, duplicates); 413 body over 1 MB; 422 invalid fields; \
  429 rate limited (see `retry-after`).

  **Write bodies** may be sent flat or wrapped under the singular resource \
  name (`{"role": {...}}`).
  """

  @tags [
    %Tag{name: "Auth", description: "Sessions and the signed-in user"},
    %Tag{name: "Users", description: "User management (users:*)"},
    %Tag{name: "Roles", description: "Roles and their assignment to users (roles:*)"},
    %Tag{
      name: "Permissions",
      description: "Permissions and their assignment to roles (permissions:*)"
    },
    %Tag{name: "Notifications", description: "Real-time notifications"},
    %Tag{name: "Health", description: "Liveness and readiness checks"},
    %Tag{name: "Service", description: "The service and this document"}
  ]

  @impl OpenApiSpex.OpenApi
  def spec do
    %OpenApi{
      openapi: "3.0.3",
      info: %Info{
        title: "Rephi API",
        version: @version,
        description: @description
      },
      # Relative: "Try it out" calls the host that serves the document.
      servers: [%Server{url: "/", description: "The host serving this document"}],
      paths: RephiWeb.Router |> OpenApiSpex.Paths.from_router() |> operation_per_verb(),
      components: %Components{
        securitySchemes: %{
          "bearerAuth" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            bearerFormat: "JWT",
            description:
              "The access token returned by login, register or a password change: \"Authorization: Bearer <token>\""
          }
        }
      },
      tags: @tags
    }
    |> OpenApiSpex.resolve_schema_modules()
  end

  # `resources` routes PUT and PATCH to the same action, so both operations
  # come out with the same id and `OpenApiSpex.Paths` tells them apart with a
  # " (2)" suffix on one of them. Give them stable ids instead: PUT keeps the
  # action's (`RephiWeb.RoleController.update`), PATCH gets `.patch` appended.
  defp operation_per_verb(paths) do
    Map.new(paths, fn
      {path, %PathItem{put: %Operation{} = put, patch: %Operation{} = patch} = item} ->
        id = base_id(put.operationId)

        if base_id(patch.operationId) == id do
          {path,
           %{
             item
             | put: %{put | operationId: id},
               patch: %{patch | operationId: id <> ".patch"}
           }}
        else
          {path, item}
        end

      other ->
        other
    end)
  end

  defp base_id(id), do: String.replace(id, ~r/ \(\d+\)\z/, "")
end
