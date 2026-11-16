defmodule RephiWeb.Plugs.RateLimit do
  @moduledoc """
  Throttles a route per client IP address.

  Each use names a bucket; the limits of the bucket come from the
  configuration, so they can change without touching code:

      # in a controller
      plug RephiWeb.Plugs.RateLimit, [bucket: :login] when action == :login

      # config/config.exs
      config :rephi, RephiWeb.Plugs.RateLimit,
        enabled: true,
        trusted_proxies: 0,
        login: [limit: 10, window_seconds: 60],
        register: [limit: 5, window_seconds: 60]

  Every request counts, successful or not. Past the limit the request is
  answered with `429` in the API error envelope and a `retry-after` header
  with the seconds left in the window; the action does not run.

  To throttle another route, add a bucket to the configuration and plug it.

  ## Options (application environment)

    * `:enabled` - `false` lets everything through. It is off in the test
      environment; `RATE_LIMIT_ENABLED` sets it at runtime.
    * `<bucket>: [limit: n, window_seconds: s]` - at most `n` requests every
      `s` seconds per address (`RATE_LIMIT_LOGIN_MAX`,
      `RATE_LIMIT_REGISTER_MAX`, `RATE_LIMIT_WINDOW_SECONDS`).
    * `:trusted_proxies` - see "Behind a reverse proxy"
      (`RATE_LIMIT_TRUSTED_PROXIES`).

  The configuration is read on every request, so a test can switch the limiter
  on with `Application.put_env/3` (and `RephiWeb.RateLimiter.reset/0` between
  tests).

  ## Limits of this limiter

  Counters are per node and in memory (see `RephiWeb.RateLimiter`): with
  several nodes the effective limit is multiplied by the number of nodes, and
  a restart forgets them. It slows down password guessing and mass
  registration from one address; it is not a substitute for limits at the
  edge (load balancer, WAF) against a distributed attack.

  IPv6 clients are counted per /64 network, since a single host usually
  controls a whole /64.

  ## Behind a reverse proxy

  By default the client address is `conn.remote_ip`, the peer of the TCP
  connection. Behind a reverse proxy or load balancer that peer is the proxy,
  so **every client shares one counter** and a single abuser can use up the
  limit for everybody.

  The `X-Forwarded-For` header is not trusted by default, because a client
  that reaches the application directly can put anything in it and dodge the
  limit. If, and only if, every request goes through your proxies, set
  `:trusted_proxies` to the number of proxies in front of the application.
  The client address is then the entry that many positions from the right of
  `X-Forwarded-For` - the one written by your outermost proxy - and entries
  further left, which the client controls, are ignored.
  """
  @behaviour Plug

  import Plug.Conn

  alias RephiWeb.{FallbackController, RateLimiter}

  @impl Plug
  def init(opts), do: Keyword.fetch!(opts, :bucket)

  @impl Plug
  def call(conn, bucket) do
    config = Application.get_env(:rephi, __MODULE__, [])

    if Keyword.get(config, :enabled, false) do
      settings = Keyword.fetch!(config, bucket)
      limit = Keyword.fetch!(settings, :limit)
      window_ms = Keyword.fetch!(settings, :window_seconds) * 1000
      key = {bucket, client_address(conn, Keyword.get(config, :trusted_proxies, 0))}

      case RateLimiter.hit(key, limit, window_ms) do
        {:allow, _count} -> conn
        {:deny, retry_after} -> too_many_requests(conn, retry_after)
      end
    else
      conn
    end
  end

  defp too_many_requests(conn, retry_after) do
    conn
    |> put_resp_header("retry-after", Integer.to_string(retry_after))
    |> FallbackController.call(
      {:error, :too_many_requests, "Too many attempts. Try again in #{retry_after} seconds."}
    )
    |> halt()
  end

  @doc """
  The address a request is counted under.

  `trusted_proxies` is the number of proxies whose `X-Forwarded-For` entry is
  trusted; with `0` the header is never read. Falls back to `conn.remote_ip`
  when the header is missing or does not hold a valid address.
  """
  @spec client_address(Plug.Conn.t(), non_neg_integer()) :: tuple()
  def client_address(conn, trusted_proxies \\ 0) do
    conn
    |> forwarded_address(trusted_proxies)
    |> Kernel.||(conn.remote_ip)
    |> network()
  end

  defp forwarded_address(_conn, trusted_proxies) when trusted_proxies < 1, do: nil

  defp forwarded_address(conn, trusted_proxies) do
    entries =
      conn
      |> get_req_header("x-forwarded-for")
      |> Enum.flat_map(&String.split(&1, ","))
      |> Enum.map(&String.trim/1)

    with entry when is_binary(entry) <- Enum.at(entries, -trusted_proxies),
         {:ok, address} <- entry |> String.to_charlist() |> :inet.parse_address() do
      address
    else
      _ -> nil
    end
  end

  # IPv4 addresses count on their own, IPv6 ones by their /64 network.
  defp network({a, b, c, d, _, _, _, _}), do: {a, b, c, d}
  defp network(address), do: address
end
