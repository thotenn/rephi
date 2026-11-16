defmodule RephiWeb.Plugs.RateLimit do
  @moduledoc """
  Throttles a route per client address (IPv6 per /64), or per signed-in user with
  `by: :user` (plugged after authentication). Each `bucket:` takes its limits from
  `config :rephi, RephiWeb.Plugs.RateLimit`; past them the answer is `429` with
  `retry-after`. Counters are per node and in memory.

  `X-Forwarded-For` is read only when `:trusted_proxies` is above 0. Set it to the
  number of proxies in front, and only if every request goes through them:
  otherwise a client can forge the header and dodge the limit.
  """
  @behaviour Plug

  import Plug.Conn

  alias RephiWeb.{FallbackController, RateLimiter}

  @impl Plug
  def init(opts) do
    by = Keyword.get(opts, :by, :ip)

    if by not in [:ip, :user] do
      raise ArgumentError, "by: must be :ip or :user, got #{inspect(by)}"
    end

    {Keyword.fetch!(opts, :bucket), by}
  end

  @impl Plug
  def call(conn, {bucket, by}) do
    config = Application.get_env(:rephi, __MODULE__, [])

    if Keyword.get(config, :enabled, false) do
      settings = Keyword.fetch!(config, bucket)
      limit = Keyword.fetch!(settings, :limit)
      window_ms = Keyword.fetch!(settings, :window_seconds) * 1000
      key = {bucket, client_key(conn, by, config)}

      case RateLimiter.hit(key, limit, window_ms) do
        {:allow, _count} -> conn
        {:deny, retry_after} -> too_many_requests(conn, retry_after)
      end
    else
      conn
    end
  end

  defp client_key(%{assigns: %{current_user: %{id: id}}}, :user, _config), do: {:user, id}

  defp client_key(conn, :ip, config),
    do: client_address(conn, Keyword.get(config, :trusted_proxies, 0))

  defp too_many_requests(conn, retry_after) do
    conn
    |> put_resp_header("retry-after", Integer.to_string(retry_after))
    |> FallbackController.call({:error, :too_many_requests, retry_message(retry_after)})
    |> halt()
  end

  @doc false
  def retry_message(1), do: "Too many attempts. Try again in 1 second."
  def retry_message(seconds), do: "Too many attempts. Try again in #{seconds} seconds."

  @doc """
  The address a request is counted under.

  Trusts the last `trusted_proxies` entries of `X-Forwarded-For` (none with `0`),
  falling back to `conn.remote_ip`.
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

  defp network({a, b, c, d, _, _, _, _}), do: {a, b, c, d}
  defp network(address), do: address
end
