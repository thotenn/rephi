defmodule RephiWeb.DashboardController do
  @moduledoc """
  `GET /api/dashboard`: counters for the signed-in user. Each counter is `nil` when the
  caller lacks the permission to see it (`users:view`, `notifications:broadcast`).
  """
  use RephiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import RephiWeb.ApiSpec.Operations

  alias Rephi.{Accounts, Notifications}
  alias RephiWeb.{Presence, Schemas}

  action_fallback RephiWeb.FallbackController

  tags ["Dashboard"]
  security bearer_auth()

  operation :show,
    summary: "Dashboard counters",
    description:
      "users.total needs users:view and notifications.sent_total needs notifications:broadcast; without them they are null. notifications.sent_by_me and sessions are for everyone.",
    responses:
      responses([
        :unauthorized,
        :password_settled,
        ok: {"The counters", Schemas.DashboardResponse}
      ])

  def show(conn, _params) do
    user = conn.assigns.current_user

    render(conn, :show,
      dashboard: %{
        users: %{total: if(can?(conn, "users:view"), do: Accounts.count_users())},
        notifications: %{
          sent_total:
            if(can?(conn, "notifications:broadcast"), do: Notifications.count_broadcasts()),
          sent_by_me: Notifications.count_sent_by(user)
        },
        sessions: Presence.online_counts()
      }
    )
  end
end
