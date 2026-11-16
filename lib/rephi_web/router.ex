defmodule RephiWeb.Router do
  use RephiWeb, :router

  # JSON never needs to load anything nor be framed, hence the strictest CSP.
  pipeline :api do
    plug :accepts, ["json"]

    plug :put_secure_browser_headers, %{
      "content-security-policy" => "default-src 'none'; frame-ancestors 'none'"
    }
  end

  # A valid access token of an existing user, or a 401. See
  # `RephiWeb.Auth.Pipeline`.
  pipeline :authenticated do
    plug RephiWeb.Auth.Pipeline
  end

  # The API documentation is only served where it is enabled
  # (`config :rephi, :swagger_enabled`, SWAGGER_ENABLED at runtime).
  pipeline :api_docs do
    plug :ensure_api_docs_enabled
    plug OpenApiSpex.Plug.PutApiSpec, module: RephiWeb.ApiSpec
  end

  pipeline :frontend do
    plug :put_secure_browser_headers
  end

  # Service descriptor. The backend has no HTML pages of its own: unknown
  # paths answer 404 as JSON (see `RephiWeb.ErrorJSON`).
  scope "/", RephiWeb do
    pipe_through :api

    get "/", RootController, :index
  end

  scope "/api", RephiWeb do
    pipe_through :api

    # Health checks for load balancers and orchestrators (no authentication)
    get "/health", HealthController, :live, log: false
    get "/health/ready", HealthController, :ready, log: false

    # Public routes
    scope "/users" do
      post "/register", AuthController, :register
      post "/login", AuthController, :login
    end

    # Protected routes
    pipe_through :authenticated

    get "/me", AuthController, :me
    put "/me/password", AuthController, :change_password
    post "/users/logout", AuthController, :logout
    post "/notifications/broadcast", NotificationController, :broadcast

    # Role management endpoints
    resources "/roles", RoleController, except: [:new, :edit]
    get "/roles/:id/permissions", RoleController, :get_role_permissions
    post "/users/:user_id/roles/:role_id", RoleController, :assign_to_user
    delete "/users/:user_id/roles/:role_id", RoleController, :remove_from_user

    # Permission management endpoints
    resources "/permissions", PermissionController, except: [:new, :edit]
    post "/roles/:role_id/permissions/:permission_id", PermissionController, :assign_to_role
    delete "/roles/:role_id/permissions/:permission_id", PermissionController, :remove_from_role

    # User management endpoints (users:view / users:edit / users:delete)
    resources "/users", UserController, only: [:index, :show, :update, :delete]
    get "/users/:id/roles", UserController, :get_user_roles
  end

  scope "/api" do
    pipe_through [:api, :api_docs]

    get "/openapi", RephiWeb.OpenApiController, :show
  end

  # Not :api: the Swagger UI page loads its scripts from a CDN, which the
  # strict CSP of :api would block.
  scope "/api" do
    pipe_through [:frontend, :api_docs]

    get "/swagger", OpenApiSpex.Plug.SwaggerUI, path: "/api/openapi", title: "Rephi API"
  end

  # Frontend apps: every directory in priv/static/apps/<name> is served at
  # /app/<name>. Adding an app does not require a new route.
  scope "/app" do
    pipe_through :frontend

    forward "/", RephiWeb.Plugs.FrontendAppPlug
  end

  # Answers 404, as if the routes did not exist, unless the documentation is
  # enabled. Read on every request so a release can switch it with an
  # environment variable.
  defp ensure_api_docs_enabled(conn, _opts) do
    if Application.get_env(:rephi, :swagger_enabled, false) do
      conn
    else
      conn
      |> RephiWeb.FallbackController.call({:error, :not_found})
      |> halt()
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:rephi, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/metrics", metrics: RephiWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
