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
    post "/users/register", AuthController, :register
    post "/users/login", AuthController, :login

    # Protected routes
    pipe_through :authenticated

    get "/me", AuthController, :me
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
        description: "Phoenix/Elixir backend with JWT authentication and real-time WebSocket communication"
      },
      securityDefinitions: %{
        Bearer: %{
          type: "apiKey",
          name: "Authorization",
          in: "header",
          description: "JWT Authorization header using the Bearer scheme. Example: \"Authorization: Bearer {token}\""
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
