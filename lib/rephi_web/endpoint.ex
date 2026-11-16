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
    # HTTPS only in production (config/prod.exs)
    secure: Application.compile_env(:rephi, :secure_session_cookie, false)
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  # `auth_token: true` lets clients send their token with the `authToken`
  # option of the JS client instead of in the URL. See `RephiWeb.UserSocket`.
  socket "/socket", RephiWeb.UserSocket,
    websocket: true,
    longpoll: false,
    auth_token: true

  # HTTP -> HTTPS redirect and HSTS, when enabled (production by default)
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

  # CORS goes before the body parser so the errors it answers (400 for
  # malformed JSON, 413 for a body over the limit) carry the headers too;
  # otherwise a browser reports them as a CORS failure. The allowed origins
  # are runtime configuration, see `RephiWeb.CORS`.
  plug CORSPlug,
    origin: &RephiWeb.CORS.origin/1,
    credentials: true,
    expose: ["retry-after"]

  # The API only takes small JSON documents, so bodies are capped at 1 MB
  # (the default is 8 MB). An endpoint that accepts uploads needs a higher
  # limit for its parser: `{:multipart, length: 20_000_000}`.
  # `RephiWeb.Plugs.BodyParser` is `Plug.Parsers` answering its own errors.
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
  Log level of a request, or `false` to keep it out of the logs.

  Health checks are polled every few seconds by load balancers and
  orchestrators, so they are not logged.
  """
  def log_level(%Plug.Conn{path_info: ["api", "health" | _]}), do: false
  def log_level(_conn), do: :info
end
