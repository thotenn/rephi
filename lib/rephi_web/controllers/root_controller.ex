defmodule RephiWeb.RootController do
  @moduledoc """
  Answers `GET /` with a tiny description of the service.

  The backend is a JSON API: there is no HTML landing page. Frontend
  applications live under `/app/<name>` (see `RephiWeb.Plugs.FrontendAppPlug`).
  """
  use RephiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import RephiWeb.ApiSpec.Operations

  alias RephiWeb.Schemas

  action_fallback RephiWeb.FallbackController

  tags ["Service"]

  operation :index,
    summary: "Describe the service",
    description: "The name of the service and where its liveness check is.",
    responses: responses(ok: {"The service", Schemas.ServiceResponse})

  def index(conn, _params) do
    json(conn, %{data: %{name: "rephi", health: ~p"/api/health"}})
  end
end
