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
  use OpenApiSpex.ControllerSpecs

  import RephiWeb.ApiSpec.Operations

  alias RephiWeb.Notifications
  alias RephiWeb.Schemas

  action_fallback RephiWeb.FallbackController

  tags ["Notifications"]

  plug AuthorizationPlug, {:permission, "notifications:broadcast"}

  operation :broadcast,
    summary: "Broadcast a notification",
    description:
      "Sends new_notification to every client joined to the user:lobby channel, with the same payload as this response. The attributes may also be wrapped under \"notification\". Requires notifications:broadcast.",
    security: bearer_auth(),
    request_body: body("The message", Schemas.NotificationRequest),
    responses:
      responses([
        :unauthorized,
        :body_errors,
        ok: {"Notification sent", Schemas.NotificationResponse},
        forbidden: "Forbidden - requires notifications:broadcast",
        unprocessable_entity: "message missing, blank, not a string or longer than 500 characters"
      ])

  def broadcast(conn, _params) do
    attrs = resource_params(conn, "notification")

    with {:ok, notification} <- Notifications.broadcast(attrs, conn.assigns.current_user) do
      render(conn, :show, notification: notification)
    end
  end
end
