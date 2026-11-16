defmodule RephiWeb.NotificationController do
  @moduledoc """
  Broadcasts notifications to the clients connected to the `user:lobby` channel.

  ## Endpoints

    * `POST /api/notifications/broadcast` - Send `message` to every connected
      client (attributes flat or wrapped under `"notification"`)

  ## Permission Requirements

  Requires the `notifications:broadcast` permission: a broadcast reaches every
  connected user, so it is not something any signed-in account may do. The
  seeds grant it to the `admin` role only.

  The event itself (topic, payload, validation) lives in
  `RephiWeb.Notifications`.
  """
  use RephiWeb, :controller
  use PhoenixSwagger

  import RephiWeb.Swagger

  alias PhoenixSwagger.Schema
  alias RephiWeb.Notifications

  action_fallback RephiWeb.FallbackController

  plug AuthorizationPlug, {:permission, "notifications:broadcast"}

  swagger_path :broadcast do
    post("/api/notifications/broadcast")
    summary("Broadcast a notification")

    description(
      "Sends new_notification to every client joined to the user:lobby channel, with the same payload as this response. The attributes may also be wrapped under \"notification\". Requires notifications:broadcast."
    )

    tag("Notifications")
    consumes("application/json")
    produces("application/json")
    bearer_auth()

    parameters do
      body(:body, Schema.ref(:NotificationRequest), "The message", required: true)
    end

    response(200, "Notification sent", Schema.ref(:NotificationResponse))
    body_errors()
    error_response(403, "Forbidden - requires notifications:broadcast")
    validation_response("message missing, blank, not a string or longer than 500 characters")
  end

  def broadcast(conn, _params) do
    attrs = resource_params(conn, "notification")

    with {:ok, notification} <- Notifications.broadcast(attrs, conn.assigns.current_user) do
      render(conn, :show, notification: notification)
    end
  end

  def swagger_definitions do
    RephiWeb.Swagger.definitions(%{
      NotificationRequest: %{
        type: :object,
        title: "Notification Request",
        description: "A broadcast",
        properties: %{
          message: %{
            type: :string,
            minLength: 1,
            maxLength: 500,
            description: "Plain text, trimmed; clients render it as text"
          }
        },
        required: [:message],
        example: %{message: "Maintenance at 18:00 UTC"}
      },
      NotificationResponse: %{
        type: :object,
        title: "Notification Response",
        description: "The notification that was broadcast, as the sockets received it",
        properties: %{
          data: %{
            type: :object,
            properties: %{
              message: %{type: :string},
              timestamp: %{type: :string, format: :"date-time"},
              type: %{type: :string, description: "Always \"general\" for now"},
              from: %{
                type: :object,
                "x-nullable": true,
                description: "The sender; null for notifications sent by the system",
                properties: %{id: %{type: :integer}, email: %{type: :string}},
                required: [:id, :email]
              }
            },
            required: [:message, :timestamp, :type, :from]
          }
        },
        required: [:data],
        example: %{
          data: %{
            message: "Maintenance at 18:00 UTC",
            timestamp: "2026-01-01T12:00:00.000000Z",
            type: "general",
            from: %{id: 1, email: "admin@example.com"}
          }
        }
      }
    })
  end
end
