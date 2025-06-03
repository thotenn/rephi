defmodule RephiWeb.Router do
  use RephiWeb, :router
  use PhoenixSwagger

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated do
    plug RephiWeb.Auth.Pipeline
    plug Guardian.Plug.EnsureAuthenticated
  end

  scope "/api", RephiWeb do
    pipe_through :api

    # Public routes
    scope "/users" do
      post "/register", AuthController, :register
      post "/login", AuthController, :login
    end

    # Protected routes
    pipe_through :authenticated

    get "/me", AuthController, :me
    post "/notifications/broadcast", NotificationController, :broadcast

    # Role management endpoints
    resources "/roles", RoleController, except: [:new, :edit]
    post "/users/:user_id/roles/:role_id", RoleController, :assign_to_user
    delete "/users/:user_id/roles/:role_id", RoleController, :remove_from_user

    # Permission management endpoints
    resources "/permissions", PermissionController, except: [:new, :edit]
    post "/roles/:role_id/permissions/:permission_id", PermissionController, :assign_to_role
    delete "/roles/:role_id/permissions/:permission_id", PermissionController, :remove_from_role

    # User management endpoints (admin only)
    resources "/users", UserController, only: [:index, :show, :update, :delete]
  end

  scope "/api/swagger" do
    forward "/", PhoenixSwagger.Plug.SwaggerUI,
      otp_app: :rephi,
      swagger_file: "swagger.json"
  end

  scope "/api/swagger" do
    pipe_through :api
    get "/swagger.json", RephiWeb.SwaggerController, :index
  end

  def swagger_info do
    %{
      info: %{
        version: "1.0",
        title: "Rephi API",
        description:
          "Phoenix/Elixir backend with JWT authentication and real-time WebSocket communication"
      },
      securityDefinitions: %{
        Bearer: %{
          type: "apiKey",
          name: "Authorization",
          in: "header",
          description:
            "JWT Authorization header using the Bearer scheme. Example: \"Authorization: Bearer {token}\""
        }
      },
      consumes: ["application/json"],
      produces: ["application/json"]
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

      live_dashboard "/dashboard", metrics: RephiWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
