defmodule RephiWeb.NotificationController do
  use RephiWeb, :controller
  use PhoenixSwagger
  alias PhoenixSwagger.Schema
  alias RephiWeb.Endpoint

  action_fallback RephiWeb.FallbackController

  swagger_path :broadcast do
    post("/api/notifications/broadcast")
    summary("Broadcast notification to all connected users")
    description("Sends a notification message to all users connected via WebSocket")
    produces("application/json")
    security([%{Bearer: []}])
    
    parameters do
      body(:body, Schema.ref(:NotificationRequest), "Notification data", required: true)
    end
    
    response(200, "Success", Schema.ref(:NotificationResponse))
    response(401, "Unauthorized")
    response(422, "Unprocessable Entity")
  end

  def broadcast(conn, %{"message" => message}) when message != "" do
    # Broadcast to all connected users
    Endpoint.broadcast!("user:lobby", "new_notification", %{
      message: message,
      timestamp: DateTime.utc_now(),
      type: "general"
    })

    conn
    |> put_status(:ok)
    |> json(%{
      message: "Notification sent successfully",
      notification: %{
        message: message,
        timestamp: DateTime.utc_now()
      }
    })
  end

  def broadcast(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{message: ["can't be blank"]}})
  end

  def swagger_definitions do
    %{
      NotificationRequest: %{
        type: :object,
        title: "Notification Request",
        description: "Notification broadcast request",
        properties: %{
          message: %{type: :string, description: "Notification message"}
        },
        required: [:message],
        example: %{
          message: "This is a test notification"
        }
      },
      NotificationResponse: %{
        type: :object,
        title: "Notification Response",
        description: "Notification broadcast response",
        properties: %{
          message: %{type: :string, description: "Success message"},
          notification: %{
            type: :object,
            properties: %{
              message: %{type: :string, description: "Notification message"},
              timestamp: %{type: :string, format: :datetime, description: "Timestamp"}
            }
          }
        },
        example: %{
          message: "Notification sent successfully",
          notification: %{
            message: "This is a test notification",
            timestamp: "2024-01-01T12:00:00Z"
          }
        }
      }
    }
  end
end