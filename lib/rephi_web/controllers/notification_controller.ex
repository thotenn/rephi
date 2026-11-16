defmodule RephiWeb.NotificationController do
  @moduledoc """
  Broadcasts notifications to the clients connected to the `user:lobby` channel.

  ## Endpoints

    * `POST /api/notifications/broadcast` - Send `message` to every connected
      client (attributes flat or wrapped under `"notification"`)
  """
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

  def broadcast(conn, _params) do
    with {:ok, %{message: message}} <- validate(resource_params(conn, "notification")) do
      notification = %{message: message, timestamp: DateTime.utc_now(), type: "general"}
      Endpoint.broadcast!("user:lobby", "new_notification", notification)

      render(conn, :show, notification: notification)
    end
  end

  defp validate(params) do
    {%{}, %{message: :string}}
    |> Ecto.Changeset.cast(params, [:message])
    |> Ecto.Changeset.validate_required([:message])
    |> Ecto.Changeset.apply_action(:validate)
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
        description: "The notification that was broadcast",
        properties: %{
          data: %{
            type: :object,
            properties: %{
              message: %{type: :string, description: "Notification message"},
              timestamp: %{type: :string, format: :"date-time", description: "Timestamp"},
              type: %{type: :string, description: "Notification type"}
            },
            required: [:message, :timestamp, :type]
          }
        },
        required: [:data],
        example: %{
          data: %{
            message: "This is a test notification",
            timestamp: "2024-01-01T12:00:00Z",
            type: "general"
          }
        }
      }
    }
  end
end
