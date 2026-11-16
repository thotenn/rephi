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

  alias PhoenixSwagger.Schema
  alias RephiWeb.Notifications

  action_fallback RephiWeb.FallbackController

  plug AuthorizationPlug, {:permission, "notifications:broadcast"}

  swagger_path :broadcast do
    post("/api/notifications/broadcast")
    summary("Broadcast notification to all connected users")

    description(
      "Sends a notification message to all users connected via WebSocket. Requires the notifications:broadcast permission."
    )

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      body(:body, Schema.ref(:NotificationRequest), "Notification data", required: true)
    end

    response(200, "Success", Schema.ref(:NotificationResponse))
    response(401, "Unauthorized")
    response(403, "Forbidden - User lacks the notifications:broadcast permission")
    response(422, "Message missing, not a string or too long")
  end

  def broadcast(conn, _params) do
    attrs = resource_params(conn, "notification")

    with {:ok, notification} <- Notifications.broadcast(attrs, conn.assigns.current_user) do
      render(conn, :show, notification: notification)
    end
  end

  def swagger_definitions do
    %{
      NotificationRequest: %{
        type: :object,
        title: "Notification Request",
        description: "Notification broadcast request",
        properties: %{
          message: %{
            type: :string,
            description: "Notification message (plain text)",
            maxLength: 500
          }
        },
        required: [:message],
        example: %{
          message: "This is a test notification"
        }
      },
      NotificationResponse: %{
        type: :object,
        title: "Notification Response",
        description: "The notification that was broadcast",
        properties: %{
          data: %{
            type: :object,
            properties: %{
              message: %{type: :string, description: "Notification message"},
              timestamp: %{type: :string, format: :"date-time", description: "Timestamp"},
              type: %{type: :string, description: "Notification type"},
              from: %{
                type: :object,
                description: "The user that sent the notification",
                properties: %{
                  id: %{type: :integer},
                  email: %{type: :string}
                }
              }
            },
            required: [:message, :timestamp, :type, :from]
          }
        },
        required: [:data],
        example: %{
          data: %{
            message: "This is a test notification",
            timestamp: "2024-01-01T12:00:00Z",
            type: "general",
            from: %{id: 1, email: "admin@example.com"}
          }
        }
      }
    }
  end
end
