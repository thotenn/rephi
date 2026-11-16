defmodule RephiWeb.SwaggerController do
  @moduledoc """
  Serves the generated Swagger (OpenAPI 2.0) document of the API.

  The document is a build artifact: `mix phx.swagger.generate` writes it to
  `priv/static/swagger.json`, which is not checked in. Until it has been
  generated the endpoint answers `404` with a hint instead of failing.

  The path can be overridden with `config :rephi, :swagger_file, "/some/path"`.
  """
  use RephiWeb, :controller
  use PhoenixSwagger

  import RephiWeb.Swagger

  action_fallback RephiWeb.FallbackController

  swagger_path :show do
    get("/api/swagger/swagger.json")
    summary("This document")

    description(
      "The Swagger 2.0 document of the API. Served only where Swagger is enabled (dev and test; SWAGGER_ENABLED=true in production), 404 otherwise. The UI is at /api/swagger."
    )

    tag("Service")
    produces("application/json")
    response(200, "The Swagger document", %{type: :object})
    error_response(404, "Swagger disabled, or the document has not been generated yet")
  end

  @hint "API specification not generated yet. Run `mix phx.swagger.generate`."

  def show(conn, _params) do
    path = file()

    if File.regular?(path) do
      conn
      |> put_resp_content_type("application/json")
      |> send_file(200, path)
    else
      {:error, :not_found, @hint}
    end
  end

  @doc """
  Absolute path of the Swagger document served by this controller.
  """
  def file do
    Application.get_env(:rephi, :swagger_file) ||
      Application.app_dir(:rephi, "priv/static/swagger.json")
  end
end
