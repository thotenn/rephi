defmodule RephiWeb.RootController do
  @moduledoc """
  Answers `GET /` with a tiny description of the service.

  The backend is a JSON API: there is no HTML landing page. Frontend
  applications live under `/app/<name>` (see `RephiWeb.Plugs.FrontendAppPlug`).
  """
  use RephiWeb, :controller

  action_fallback RephiWeb.FallbackController

  def index(conn, _params) do
    json(conn, %{data: %{name: "rephi", health: ~p"/api/health"}})
  end
end
