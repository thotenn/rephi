defmodule RephiWeb.AppController do
  use RephiWeb, :controller

  @apps [:dashboard, :landing, :ecommerce, :admin]

  def serve_app(conn, %{"app" => app}) when is_binary(app) do
    app_atom = String.to_existing_atom(app)

    if app_atom in @apps do
      serve_spa(conn, app_atom)
    else
      conn
      |> put_status(:not_found)
      |> text("Application not found")
    end
  rescue
    ArgumentError ->
      conn
      |> put_status(:not_found)
      |> text("Application not found")
  end

  defp serve_spa(conn, app) do
    csrf_token = Phoenix.Controller.get_csrf_token()

    html_content = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <meta name="csrf-token" content="#{csrf_token}">
      <title>Rephi #{String.capitalize(to_string(app))}</title>
      <link rel="stylesheet" href="/#{app}/assets/index.css">
    </head>
    <body>
      <div id="root"></div>
      <script type="module" src="/#{app}/assets/index.js"></script>
    </body>
    </html>
    """

    conn
    |> put_resp_header("content-type", "text/html")
    |> send_resp(200, html_content)
  end
end
