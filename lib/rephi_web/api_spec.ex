defmodule RephiWeb.ApiSpec do
  @moduledoc """
  The OpenAPI 3.0 document: paths from the router's `operation`s, schemas from
  `RephiWeb.Schemas.*`. Served at `/api/openapi`, checked by `api_contract_test.exs`.
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
  records, last admin, duplicates, cycles in the role hierarchy); 413 body \
  over 1 MB; 422 invalid fields; 429 rate limited (see `retry-after`).

  **Reset passwords.** After an administrator resets a user's password \
  (`POST /api/users/{id}/password`), that user's session reports \
  `must_change_password: true` and every authenticated route except \
  `GET /api/me`, `PUT /api/me/password` and `POST /api/users/logout` answers \
  403 until the user sets a new password.

  **Write bodies** may be sent flat or wrapped under the singular resource \
  name (`{"role": {...}}`).
  """

  @tags [
    %Tag{name: "Auth", description: "Sessions and the signed-in user"},
    %Tag{name: "Users", description: "User management (users:*)"},
    %Tag{
      name: "Roles",
      description: "Roles, their hierarchy and their assignment to users (roles:*)"
    },
    %Tag{
      name: "Permissions",
      description: "Permissions and their assignment to roles and users (permissions:*)"
    },
    %Tag{name: "Notifications", description: "Real-time notifications"},
    %Tag{name: "Dashboard", description: "Counters for the signed-in user"},
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

  # PUT and PATCH of `resources` share an action; `OpenApiSpex.Paths` would
  # suffix one id with " (2)" depending on map order. PATCH gets ".patch".
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
