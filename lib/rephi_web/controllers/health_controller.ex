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

  alias PhoenixSwagger.Schema
  alias Rephi.Health

  action_fallback RephiWeb.FallbackController

  swagger_path :live do
    get("/api/health")
    summary("Liveness check")
    description("Tells whether the application is running. Does not check the database.")
    produces("application/json")

    response(200, "The application is running", Schema.ref(:HealthResponse))
  end

  def live(conn, _params) do
    render(conn, :show, checks: %{})
  end

  swagger_path :ready do
    get("/api/health/ready")
    summary("Readiness check")
    description("Tells whether the application can serve requests: the database must answer.")
    produces("application/json")

    response(200, "The application is ready", Schema.ref(:HealthResponse))
    response(503, "A dependency is unavailable", Schema.ref(:ErrorResponse))
  end

  def ready(conn, _params) do
    case Health.check_database() do
      :ok -> render(conn, :show, checks: %{database: "ok"})
      {:error, :database_unavailable} -> {:error, :service_unavailable, "Database unavailable"}
    end
  end

  def swagger_definitions do
    %{
      HealthResponse: %{
        type: :object,
        title: "Health Response",
        description: "Result of a health check",
        properties: %{
          data: %{
            type: :object,
            properties: %{
              status: %{type: :string, description: "Always \"ok\" on a 200"},
              checks: %{
                type: :object,
                description: "Dependencies that were verified (readiness only)",
                additionalProperties: %{type: :string}
              }
            },
            required: [:status]
          }
        },
        required: [:data],
        example: %{data: %{status: "ok", checks: %{database: "ok"}}}
      }
    }
  end
end
