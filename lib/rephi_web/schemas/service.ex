defmodule RephiWeb.Schemas.ServiceResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    RephiWeb.Schemas.data(
      %Schema{
        type: :object,
        properties: %{
          name: %Schema{type: :string},
          health: %Schema{type: :string, description: "Path of the liveness check"}
        },
        required: [:name, :health]
      },
      description: "The service",
      example: %{data: %{name: "rephi", health: "/api/health"}}
    ),
    struct?: false
  )
end

defmodule RephiWeb.Schemas.HealthResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    RephiWeb.Schemas.data(
      %Schema{
        type: :object,
        properties: %{status: %Schema{type: :string, enum: ["ok"]}},
        required: [:status]
      },
      description: "The application is running",
      example: %{data: %{status: "ok"}}
    ),
    struct?: false
  )
end

defmodule RephiWeb.Schemas.ReadinessResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    RephiWeb.Schemas.data(
      %Schema{
        type: :object,
        properties: %{
          status: %Schema{type: :string, enum: ["ok"]},
          checks: %Schema{
            type: :object,
            description: "Each dependency checked, \"ok\"",
            properties: %{database: %Schema{type: :string, enum: ["ok"]}},
            required: [:database]
          }
        },
        required: [:status, :checks]
      },
      description: "The application and the dependencies it was checked against are up",
      example: %{data: %{status: "ok", checks: %{database: "ok"}}}
    ),
    struct?: false
  )
end

defmodule RephiWeb.Schemas.OpenApiDocument do
  require OpenApiSpex

  OpenApiSpex.schema(
    %{
      description: "An OpenAPI 3.0 document (this one)",
      type: :object,
      example: %{openapi: "3.0.3", info: %{title: "Rephi API", version: "0.2.0"}, paths: %{}}
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.NotificationRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "A broadcast",
      type: :object,
      properties: %{
        message: %Schema{
          type: :string,
          minLength: 1,
          maxLength: 500,
          description: "Plain text, trimmed; clients render it as text"
        }
      },
      required: [:message],
      example: %{message: "Maintenance at 18:00 UTC"}
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.Notification do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description:
        "A notification, as the sockets of the user:lobby channel receive it (event new_notification)",
      type: :object,
      properties: %{
        message: %Schema{type: :string},
        timestamp: RephiWeb.Schemas.timestamp(),
        type: %Schema{type: :string, description: "Always \"general\" for now"},
        from: %Schema{
          type: :object,
          nullable: true,
          description: "The sender; null for notifications sent by the system",
          properties: %{id: %Schema{type: :integer}, email: %Schema{type: :string}},
          required: [:id, :email]
        }
      },
      required: [:message, :timestamp, :type, :from]
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.NotificationResponse do
  require OpenApiSpex

  OpenApiSpex.schema(
    RephiWeb.Schemas.data(RephiWeb.Schemas.Notification,
      description: "The notification that was broadcast, as the sockets received it",
      example: %{
        data: %{
          message: "Maintenance at 18:00 UTC",
          timestamp: "2026-01-01T12:00:00.000000Z",
          type: "general",
          from: %{id: 1, email: "admin@example.com"}
        }
      }
    ),
    struct?: false
  )
end
