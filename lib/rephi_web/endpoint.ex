defmodule RephiWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :rephi

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_rephi_key",
    signing_salt: "vZra/yRC",
    same_site: "Lax",
    secure: Application.compile_env(:rephi, :secure_session_cookie, false)
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  # `auth_token: true` lets the JS client's `authToken` keep the token out of the URL.
  socket "/socket", RephiWeb.UserSocket,
    websocket: true,
    longpoll: false,
    auth_token: true

  plug RephiWeb.Plugs.ForceSSL

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :rephi,
    gzip: false,
    only: RephiWeb.static_paths()

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :rephi
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId

  plug Plug.Telemetry,
    event_prefix: [:phoenix, :endpoint],
    log: {__MODULE__, :log_level, []}

  # Before the body parser, so its 400/413 errors carry the CORS headers too.
  plug CORSPlug,
    origin: &RephiWeb.CORS.origin/1,
    credentials: true,
    expose: ["retry-after"]

  # 1 MB instead of the default 8 MB: the API only takes small JSON documents.
  plug RephiWeb.Plugs.BodyParser,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    length: 1_000_000,
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options

  plug RephiWeb.Router

  @doc """
  Log level of a request, or `false` for the health checks polled by load balancers.
  """
  def log_level(%Plug.Conn{path_info: ["api", "health" | _]}), do: false
  def log_level(_conn), do: :info
end
