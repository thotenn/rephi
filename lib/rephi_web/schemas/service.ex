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
      description: "A notification to send",
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
        "A notification, as the sockets receive it (event new_notification on user:lobby or user:<id>)",
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
      description: "The notification that was sent, as the sockets received it",
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

defmodule RephiWeb.Schemas.DashboardUsers do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      type: :object,
      properties: %{
        total: %Schema{
          type: :integer,
          nullable: true,
          description: "Every account; null without users:view"
        }
      },
      required: [:total]
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.DashboardNotifications do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      type: :object,
      properties: %{
        sent_total: %Schema{
          type: :integer,
          nullable: true,
          description: "Broadcasts sent by anyone; null without notifications:broadcast"
        },
        sent_by_me: %Schema{
          type: :integer,
          description: "Notifications the caller sent (broadcasts and tests to itself)"
        }
      },
      required: [:sent_total, :sent_by_me]
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.DashboardSessions do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description:
        "Who is connected to the user:lobby channel right now (Phoenix Presence); clients joined to it keep it current with presence_state / presence_diff",
      type: :object,
      properties: %{
        online_users: %Schema{type: :integer, description: "Distinct users"},
        connections: %Schema{type: :integer, description: "Sockets (a user may have several)"}
      },
      required: [:online_users, :connections]
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.Dashboard do
  require OpenApiSpex

  OpenApiSpex.schema(
    %{
      description:
        "Counters for the dashboard. A counter the caller may not see is null, never left out",
      type: :object,
      properties: %{
        users: RephiWeb.Schemas.DashboardUsers,
        notifications: RephiWeb.Schemas.DashboardNotifications,
        sessions: RephiWeb.Schemas.DashboardSessions
      },
      required: [:users, :notifications, :sessions]
    },
    struct?: false
  )
end

defmodule RephiWeb.Schemas.DashboardResponse do
  require OpenApiSpex

  OpenApiSpex.schema(
    RephiWeb.Schemas.data(RephiWeb.Schemas.Dashboard,
      example: %{
        data: %{
          users: %{total: 42},
          notifications: %{sent_total: 17, sent_by_me: 3},
          sessions: %{online_users: 5, connections: 7}
        }
      }
    ),
    struct?: false
  )
end
