defmodule RephiWeb.RootController do
  @moduledoc """
  Answers `GET /` with a tiny description of the service.

  The backend is a JSON API: there is no HTML landing page. Frontend
  applications live under `/app/<name>` (see `RephiWeb.Plugs.FrontendAppPlug`).
  """
  use RephiWeb, :controller
  use PhoenixSwagger

  alias PhoenixSwagger.Schema

  action_fallback RephiWeb.FallbackController

  swagger_path :index do
    get("/")
    summary("Describe the service")
    description("The name of the service and where its liveness check is.")
    tag("Service")
    produces("application/json")
    response(200, "The service", Schema.ref(:ServiceResponse))
  end

  def index(conn, _params) do
    json(conn, %{data: %{name: "rephi", health: ~p"/api/health"}})
  end

  def swagger_definitions do
    RephiWeb.Swagger.definitions(%{
      ServiceResponse: %{
        type: :object,
        title: "Service Response",
        properties: %{
          data: %{
            type: :object,
            properties: %{
              name: %{type: :string},
              health: %{type: :string, description: "Path of the liveness check"}
            },
            required: [:name, :health]
          }
        },
        required: [:data],
        example: %{data: %{name: "rephi", health: "/api/health"}}
      }
    })
  end
end
