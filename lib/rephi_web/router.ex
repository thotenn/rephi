defmodule RephiWeb.Router do
  use RephiWeb, :router
  use PhoenixSwagger

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
  pipeline :swagger do
    plug :ensure_swagger_enabled
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

  # API documentation. The JSON document has its own route, declared before
  # the Swagger UI forward so it is served with a content type and answers a
  # clean 404 while it has not been generated (`mix phx.swagger.generate`).
  scope "/api/swagger" do
    pipe_through [:api, :swagger]

    get "/swagger.json", RephiWeb.SwaggerController, :show
  end

  scope "/api/swagger" do
    pipe_through :swagger

    forward "/", PhoenixSwagger.Plug.SwaggerUI,
      otp_app: :rephi,
      swagger_file: "swagger.json"
  end

  # Frontend apps: every directory in priv/static/apps/<name> is served at
  # /app/<name>. Adding an app does not require a new route.
  scope "/app" do
    pipe_through :frontend

    forward "/", RephiWeb.Plugs.FrontendAppPlug
  end

  # Answers 404, as if the routes did not exist, unless Swagger is enabled.
  # Read on every request so a release can switch it with an environment
  # variable.
  defp ensure_swagger_enabled(conn, _opts) do
    if Application.get_env(:rephi, :swagger_enabled, false) do
      conn
    else
      conn
      |> RephiWeb.FallbackController.call({:error, :not_found})
      |> halt()
    end
  end

  @api_version Mix.Project.config()[:version]

  @api_description """
  Phoenix JSON API with JWT authentication, role-based access control and \
  real-time notifications over WebSockets (`/socket`, channel `user:lobby`).

  **Envelopes.** A successful response with a body is `{"data": ...}`; a \
  paginated list adds `"meta": {"page", "page_size", "total", "total_pages"}` \
  (`page` from 1, `page_size` 50 by default, at most 100). An error is \
  `{"errors": {"detail": "message"}}`, or `{"errors": {"field": ["message"]}}` \
  for a validation error (422).

  **Status codes.** 400 malformed JSON or missing credentials; 401 missing, \
  invalid, expired or revoked token; 403 missing permission, or granting what \
  the caller does not hold; 404 unknown record or route (also for an id that \
  is not a positive integer); 409 the change conflicts with the data (system \
  records, last admin, duplicates); 413 body over 1 MB; 422 invalid fields; \
  429 rate limited (see `retry-after`).

  **Write bodies** may be sent flat or wrapped under the singular resource \
  name (`{"role": {...}}`).
  """

  def swagger_info do
    %{
      info: %{
        version: @api_version,
        title: "Rephi API",
        description: @api_description
      },
      securityDefinitions: %{
        Bearer: %{
          type: "apiKey",
          name: "Authorization",
          in: "header",
          description:
            "The access token returned by login, register or a password change: \"Authorization: Bearer <token>\""
        }
      },
      consumes: ["application/json"],
      produces: ["application/json"],
      tags: [
        %{name: "Auth", description: "Sessions and the signed-in user"},
        %{name: "Users", description: "User management (users:*)"},
        %{name: "Roles", description: "Roles and their assignment to users (roles:*)"},
        %{
          name: "Permissions",
          description: "Permissions and their assignment to roles (permissions:*)"
        },
        %{name: "Notifications", description: "Real-time notifications"},
        %{name: "Health", description: "Liveness and readiness checks"},
        %{name: "Service", description: "The service and this document"}
      ]
    }
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
