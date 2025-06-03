defmodule RephiWeb.SwaggerController do
  use RephiWeb, :controller

  def index(conn, _params) do
    conn
    |> put_resp_content_type("application/json")
    |> json(RephiWeb.Router.swagger_info())
  end
end
