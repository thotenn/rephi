defmodule RephiWeb.OpenApiController do
  @moduledoc """
  `GET /api/openapi` (`OpenApiSpex.Plug.RenderSpec`). A controller rather than the plug
  routed directly so the document describes this route too.
  """
  use RephiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import RephiWeb.ApiSpec.Operations

  alias RephiWeb.Schemas

  tags ["Service"]

  operation :show,
    summary: "This document",
    description:
      "The OpenAPI 3.0 document of the API. Served only where the documentation is enabled (dev and test; SWAGGER_ENABLED=true in production), 404 otherwise. The Swagger UI is at /api/swagger.",
    responses:
      responses(
        ok: {"The OpenAPI document", Schemas.OpenApiDocument},
        not_found: "The documentation is disabled"
      )

  def show(conn, _params), do: OpenApiSpex.Plug.RenderSpec.call(conn, [])
end
