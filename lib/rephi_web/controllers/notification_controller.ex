defmodule RephiWeb.NotificationController do
  @moduledoc """
  Sends notifications: `broadcast` to every connected client (requires
  `notifications:broadcast`), `me` to the caller's own connections (rate limited
  per user).
  """
  use RephiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import RephiWeb.ApiSpec.Operations

  alias RephiWeb.Notifications
  alias RephiWeb.Schemas

  action_fallback RephiWeb.FallbackController

  tags ["Notifications"]

  plug AuthorizationPlug, {:permission, "notifications:broadcast"} when action == :broadcast

  plug RephiWeb.Plugs.RateLimit,
       [bucket: :self_notification, by: :user] when action == :notify_self

  operation :broadcast,
    summary: "Broadcast a notification",
    description:
      "Sends new_notification to every client joined to the user:lobby channel, with the same payload as this response. The attributes may also be wrapped under \"notification\". Requires notifications:broadcast.",
    security: bearer_auth(),
    request_body: body("The message", Schemas.NotificationRequest),
    responses:
      responses([
        :unauthorized,
        :password_settled,
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

  operation :notify_self,
    summary: "Send a test notification to yourself",
    description:
      "Sends new_notification, with the same payload as this response, only to the caller's own topic user:<id>; no other user receives it. The attributes may also be wrapped under \"notification\". Any signed-in user; at most 5 per minute per user by default.",
    security: bearer_auth(),
    request_body: body("The message", Schemas.NotificationRequest),
    responses:
      responses([
        :unauthorized,
        :password_settled,
        :body_errors,
        ok: {"Notification sent to the caller", Schemas.NotificationResponse},
        unprocessable_entity:
          "message missing, blank, not a string or longer than 500 characters",
        too_many_requests:
          "Too many test notifications from this user; retry after the retry-after header"
      ])

  def notify_self(conn, _params) do
    attrs = resource_params(conn, "notification")

    with {:ok, notification} <- Notifications.notify_self(conn.assigns.current_user, attrs) do
      render(conn, :show, notification: notification)
    end
  end
end
