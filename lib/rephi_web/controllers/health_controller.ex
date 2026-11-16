defmodule RephiWeb.HealthController do
  @moduledoc """
  Unauthenticated health checks for load balancers and orchestrators.

  ## Endpoints

    * `GET /api/health` - Liveness: the application is up and answering HTTP.
      Never touches the database.
    * `GET /api/health/ready` - Readiness: the application can serve requests,
      which requires the database. Answers `503` when it cannot be reached.
  """
  use RephiWeb, :controller
  use PhoenixSwagger

  import RephiWeb.Swagger

  alias PhoenixSwagger.Schema
  alias Rephi.Health

  action_fallback RephiWeb.FallbackController

  swagger_path :live do
    get("/api/health")
    summary("Liveness check")
    description("Tells whether the application is running. Does not check the database.")
    tag("Health")
    produces("application/json")
    response(200, "The application is running", Schema.ref(:HealthResponse))
  end

  def live(conn, _params) do
    render(conn, :show, checks: %{})
  end

  swagger_path :ready do
    get("/api/health/ready")
    summary("Readiness check")

    description(
      "Tells whether the application can serve requests: the database must answer within 1 second."
    )

    tag("Health")
    produces("application/json")
    response(200, "The application is ready", Schema.ref(:ReadinessResponse))
    error_response(503, "Database unavailable")
  end

  def ready(conn, _params) do
    case Health.check_database() do
      :ok -> render(conn, :show, checks: %{database: "ok"})
      {:error, :database_unavailable} -> {:error, :service_unavailable, "Database unavailable"}
    end
  end

  def swagger_definitions do
    RephiWeb.Swagger.definitions(%{
      HealthResponse: %{
        type: :object,
        title: "Health Response",
        description: "The application is running",
        properties: %{
          data: %{
            type: :object,
            properties: %{status: %{type: :string, enum: ["ok"]}},
            required: [:status]
          }
        },
        required: [:data],
        example: %{data: %{status: "ok"}}
      },
      ReadinessResponse: %{
        type: :object,
        title: "Readiness Response",
        description: "The application and the dependencies it was checked against are up",
        properties: %{
          data: %{
            type: :object,
            properties: %{
              status: %{type: :string, enum: ["ok"]},
              checks: %{
                type: :object,
                description: "Each dependency checked, \"ok\"",
                properties: %{database: %{type: :string, enum: ["ok"]}},
                required: [:database]
              }
            },
            required: [:status, :checks]
          }
        },
        required: [:data],
        example: %{data: %{status: "ok", checks: %{database: "ok"}}}
      }
    })
  end
end
