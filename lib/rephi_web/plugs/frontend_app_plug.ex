defmodule RephiWeb.Plugs.FrontendAppPlug do
  @moduledoc """
  Plug for serving frontend applications with CSRF token injection.
  
  This plug serves static HTML files from priv/static/apps/ and injects
  the CSRF token into the HTML before sending it to the client.
  
  ## Usage
  
      # In router.ex
      forward "/app/example", RephiWeb.Plugs.FrontendAppPlug, app: "example"
  
  The plug will:
  1. Serve the index.html from priv/static/apps/{app_name}/
  2. Inject CSRF token into a meta tag or script tag
  3. Serve other static assets without modification
  """

  import Plug.Conn
  alias Phoenix.Controller

  def init(opts) do
    app = Keyword.fetch!(opts, :app)
    %{app: app, static_path: Path.join(["priv", "static", "apps", app])}
  end

  def call(conn, %{app: app, static_path: static_path}) do
    conn = assign(conn, :app, app)
    request_path = conn.request_path
    app_prefix = "/app/#{app}"
    
    # Remove the app prefix to get the actual file path
    file_path = String.replace_leading(request_path, app_prefix, "")
    file_path = if file_path == "" or file_path == "/", do: "/index.html", else: file_path
    
    full_path = Path.join(static_path, file_path)
    
    cond do
      # Serve index.html with CSRF token injection
      String.ends_with?(file_path, "index.html") and File.exists?(full_path) ->
        serve_html_with_csrf(conn, full_path)
      
      # Serve other static files
      File.exists?(full_path) ->
        serve_static_file(conn, full_path)
      
      # Try index.html for routes (SPA support)
      true ->
        index_path = Path.join(static_path, "index.html")
        if File.exists?(index_path) do
          serve_html_with_csrf(conn, index_path)
        else
          conn
          |> send_resp(404, "Not found")
          |> halt()
        end
    end
  end

  defp serve_html_with_csrf(conn, file_path) do
    # Ensure we have session for CSRF token
    conn = conn
    |> Plug.Conn.fetch_session()
    |> Plug.Conn.fetch_query_params()
    
    csrf_token = Controller.get_csrf_token()
    
    html_content = File.read!(file_path)
    
    # Inject CSRF token as a meta tag in the head
    csrf_meta_tag = ~s(<meta name="csrf-token" content="#{csrf_token}">)
    
    # Also inject as a JavaScript variable for easy access
    csrf_script = """
    <script>
      window.__CSRF_TOKEN__ = "#{csrf_token}";
    </script>
    """
    
    # Inject both the meta tag and script before closing head tag
    modified_html = html_content
    |> String.replace("</head>", "#{csrf_meta_tag}\n#{csrf_script}\n</head>")
    
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, modified_html)
    |> halt()
  end

  defp serve_static_file(conn, file_path) do
    content_type = MIME.from_path(file_path)
    
    conn
    |> put_resp_content_type(content_type)
    |> send_file(200, file_path)
    |> halt()
  end
end