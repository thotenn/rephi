# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Development only: export the variables of `.env` (if the file exists) before
# anything below reads the environment. Variables that are already set win,
# tests never read the file, and a release only sees the real environment.
# See `Rephi.DotEnv` in config/dotenv.exs.
Code.require_file("dotenv.exs", __DIR__)

if config_env() == :dev do
  Rephi.DotEnv.load(Path.expand("../.env", __DIR__))
end

config :rephi,
  ecto_repos: [Rephi.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :rephi, RephiWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: RephiWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Rephi.PubSub,
  live_view: [signing_salt: "gWq+Hbvx"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :rephi, Rephi.Mailer, adapter: Swoosh.Adapters.Local

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# JWT authentication.
#
# There is no `secret_key` here on purpose: config/dev.exs and config/test.exs
# carry their own throwaway keys, and production must provide
# GUARDIAN_SECRET_KEY (config/runtime.exs refuses to boot without it).
#
# Tokens are access tokens with no refresh flow, so `ttl` is the longest a
# session lasts (TOKEN_TTL_SECONDS overrides it at runtime).
config :rephi, RephiWeb.Auth.Guardian,
  issuer: "rephi",
  verify_issuer: true,
  ttl: {24, :hours}

# Origins allowed to call the API from a browser (CORS) and, in production, to
# open the WebSocket. Exact origins ("https://app.example.com") or a wildcard
# for the leftmost labels of the host ("https://*.example.pages.dev").
# CORS_ORIGINS overrides it at runtime. See `RephiWeb.CORS`.
config :rephi, :cors_origins, []

# Request throttling for the public authentication endpoints, per client IP.
# See `RephiWeb.Plugs.RateLimit` for every option.
config :rephi, RephiWeb.Plugs.RateLimit,
  enabled: true,
  trusted_proxies: 0,
  login: [limit: 10, window_seconds: 60],
  register: [limit: 5, window_seconds: 60]

# Seeding an administrator requires ADMIN_EMAIL / ADMIN_PASSWORD unless an
# environment says otherwise (config/dev.exs, config/test.exs). See `Rephi.Seeds`.
config :rephi, Rephi.Seeds, admin: :required

# Authorization. `admin_role` names the administrator role: at least one user
# always keeps it, and its holders can grant any role or permission. See
# `Rephi.Authorization`.
config :rephi, Rephi.Authorization, admin_role: "admin"

# The role every new account gets on registration (`nil`: none). See
# `Rephi.Accounts.register_user/1`.
config :rephi, Rephi.Accounts, default_role: "user"

# /api/openapi and /api/swagger are served only where this is true (dev and
# test). SWAGGER_ENABLED overrides it at runtime.
config :rephi, :swagger_enabled, false

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
