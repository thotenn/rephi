import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
#
# Every variable read here is listed and explained in `.env.example`.

# ## Reading the environment
#
# An empty variable counts as unset: container tooling passes `VAR=` for
# values that were never filled in, and that must not replace a default (or
# satisfy a required secret) with an empty string.
env = fn name ->
  case System.get_env(name) do
    nil -> nil
    value -> if String.trim(value) == "", do: nil, else: String.trim(value)
  end
end

env_flag = fn name, default ->
  case env.(name) do
    nil -> default
    value when value in ~w(true 1 yes on) -> true
    value when value in ~w(false 0 no off) -> false
    value -> raise "environment variable #{name} must be true or false, got: #{inspect(value)}"
  end
end

env_integer = fn name, min ->
  with value when is_binary(value) <- env.(name) do
    case Integer.parse(value) do
      {integer, ""} when integer >= min ->
        integer

      _ ->
        raise "environment variable #{name} must be an integer >= #{min}, got: #{inspect(value)}"
    end
  end
end

env_list = fn name ->
  with value when is_binary(value) <- env.(name) do
    value |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
  end
end

# `true`, `false`, or a comma separated list of origins.
env_check_origin = fn default ->
  case env.("CHECK_ORIGIN") do
    nil -> default
    value when value in ~w(true false) -> value == "true"
    _list -> env_list.("CHECK_ORIGIN")
  end
end

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/rephi start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :rephi, RephiWeb.Endpoint, server: true
end

# ## Optional settings (development and production)
#
# The test environment is configured only by config/test.exs, so the suite
# does not depend on the shell it runs in.
if config_env() != :test do
  if ttl = env_integer.("TOKEN_TTL_SECONDS", 1) do
    config :rephi, RephiWeb.Auth.Guardian, ttl: {ttl, :seconds}
  end

  if origins = env_list.("CORS_ORIGINS") do
    config :rephi, :cors_origins, origins
  end

  if env.("SWAGGER_ENABLED") do
    config :rephi, :swagger_enabled, env_flag.("SWAGGER_ENABLED", false)
  end

  if env.("RATE_LIMIT_ENABLED") do
    config :rephi, RephiWeb.Plugs.RateLimit, enabled: env_flag.("RATE_LIMIT_ENABLED", true)
  end

  if limit = env_integer.("RATE_LIMIT_LOGIN_MAX", 1) do
    config :rephi, RephiWeb.Plugs.RateLimit, login: [limit: limit]
  end

  if limit = env_integer.("RATE_LIMIT_REGISTER_MAX", 1) do
    config :rephi, RephiWeb.Plugs.RateLimit, register: [limit: limit]
  end

  if window = env_integer.("RATE_LIMIT_WINDOW_SECONDS", 1) do
    config :rephi, RephiWeb.Plugs.RateLimit,
      login: [window_seconds: window],
      register: [window_seconds: window]
  end

  # Number of reverse proxies in front of the app whose X-Forwarded-For entry
  # can be trusted. 0 (the default) never reads the header.
  if proxies = env_integer.("RATE_LIMIT_TRUSTED_PROXIES", 0) do
    config :rephi, RephiWeb.Plugs.RateLimit, trusted_proxies: proxies
  end
end

if config_env() == :dev do
  # Development has working defaults for all of these in config/dev.exs.
  if secret = env.("GUARDIAN_SECRET_KEY") do
    config :rephi, RephiWeb.Auth.Guardian, secret_key: secret
  end

  if host = env.("PHX_HOST") do
    config :rephi, RephiWeb.Endpoint, url: [host: host]
  end

  if env.("CHECK_ORIGIN") do
    config :rephi, RephiWeb.Endpoint, check_origin: env_check_origin.(false)
  end
end

if config_env() == :prod do
  database_url =
    env.("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if env.("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :rephi, Rephi.Repo,
    # ssl: true,
    url: database_url,
    pool_size: env_integer.("POOL_SIZE", 1) || 10,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    env.("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  # The key that signs every JWT. Whoever knows it can forge a token for any
  # user, so there is no default: each deployment needs its own.
  guardian_secret =
    env.("GUARDIAN_SECRET_KEY") ||
      raise """
      environment variable GUARDIAN_SECRET_KEY is missing.
      You can generate one by calling: mix guardian.gen.secret
      """

  if byte_size(guardian_secret) < 32 do
    raise """
    environment variable GUARDIAN_SECRET_KEY is too short (#{byte_size(guardian_secret)} bytes, at least 32 are required).
    You can generate one by calling: mix guardian.gen.secret
    """
  end

  config :rephi, RephiWeb.Auth.Guardian, secret_key: guardian_secret

  # The public host name of the API. It is what the WebSocket origin check
  # compares against, so a wrong value shows up as "the socket never connects".
  host =
    env.("PHX_HOST") ||
      raise """
      environment variable PHX_HOST is missing.
      Set it to the public host name of this service, for example: api.example.com
      """

  port = env_integer.("PORT", 1) || 4000

  config :rephi, :dns_cluster_query, env.("DNS_CLUSTER_QUERY")

  # Browsers on other origins: CORS_ORIGINS feeds both CORS (above) and, unless
  # CHECK_ORIGIN says otherwise, the WebSocket origin check, which accepts the
  # host of this service plus those origins.
  cors_origins = env_list.("CORS_ORIGINS") || []

  config :rephi, RephiWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    check_origin: env_check_origin.(["//#{host}" | cors_origins]),
    secret_key_base: secret_key_base

  # ## HTTPS
  #
  # Plain HTTP requests are redirected to HTTPS and HTTPS responses carry
  # HSTS. The scheme is taken from X-Forwarded-Proto, so this works behind a
  # reverse proxy or load balancer that terminates TLS (the usual setup).
  # Health checks and requests to localhost are never redirected.
  #
  # Set FORCE_SSL=false only if something else already guarantees HTTPS and
  # the redirect gets in the way.
  #
  # The options are the ones of `Plug.SSL`. See `RephiWeb.Plugs.ForceSSL`.
  if env_flag.("FORCE_SSL", true) do
    config :rephi, :force_ssl,
      rewrite_on: [:x_forwarded_proto],
      hsts: true,
      exclude: [
        hosts: ["localhost", "127.0.0.1"],
        paths: ["/api/health", "/api/health/ready"]
      ]
  else
    config :rephi, :force_ssl, false
  end

  # To terminate TLS in the application itself instead of in a proxy, add an
  # `https:` entry to the endpoint configuration. See
  # https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  #     config :rephi, RephiWeb.Endpoint,
  #       https: [
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :rephi, Rephi.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
