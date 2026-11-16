defmodule RephiWeb.SwaggerController do
  @moduledoc """
  Serves the generated Swagger (OpenAPI 2.0) document of the API.

  The document is a build artifact: `mix phx.swagger.generate` writes it to
  `priv/static/swagger.json`, which is not checked in. Until it has been
  generated the endpoint answers `404` with a hint instead of failing.

  The path can be overridden with `config :rephi, :swagger_file, "/some/path"`.
  """
  use RephiWeb, :controller

  action_fallback RephiWeb.FallbackController

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
