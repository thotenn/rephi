defmodule RephiWeb.HealthController do
  @moduledoc """
  Unauthenticated health checks: `GET /api/health` (liveness, no database) and
  `GET /api/health/ready` (readiness, `503` without the database).
  """
  use RephiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import RephiWeb.ApiSpec.Operations

  alias Rephi.Health
  alias RephiWeb.Schemas

  action_fallback RephiWeb.FallbackController

  tags ["Health"]

  operation :live,
    summary: "Liveness check",
    description: "Tells whether the application is running. Does not check the database.",
    responses: responses(ok: {"The application is running", Schemas.HealthResponse})

  def live(conn, _params) do
    render(conn, :show, checks: %{})
  end

  operation :ready,
    summary: "Readiness check",
    description:
      "Tells whether the application can serve requests: the database must answer within 1 second.",
    responses:
      responses(
        ok: {"The application is ready", Schemas.ReadinessResponse},
        service_unavailable: "Database unavailable"
      )

  def ready(conn, _params) do
    case Health.check_database() do
      :ok -> render(conn, :show, checks: %{database: "ok"})
      {:error, :database_unavailable} -> {:error, :service_unavailable, "Database unavailable"}
    end
  end
end
