defmodule RephiWeb.Plugs.RateLimitTest do
  @moduledoc """
  SEC-12. The limiter is off in the test environment; these tests turn it on
  for themselves, which is why they cannot run concurrently with the rest.
  """
  use RephiWeb.ConnCase, async: false

  alias RephiWeb.Plugs.RateLimit
  alias RephiWeb.RateLimiter

  @credentials %{"email" => "nobody@example.com", "password" => "wrong-password"}

  setup do
    put_app_env(RateLimit,
      enabled: true,
      trusted_proxies: 0,
      login: [limit: 3, window_seconds: 60],
      register: [limit: 2, window_seconds: 60]
    )

    RateLimiter.reset()
    on_exit(&RateLimiter.reset/0)
    :ok
  end

  defp login(ip \\ {10, 0, 0, 1}, headers \\ []) do
    headers
    |> Enum.reduce(%{build_conn() | remote_ip: ip}, fn {k, v}, conn ->
      put_req_header(conn, k, v)
    end)
    |> post(~p"/api/users/login", @credentials)
  end

  defp register(n, ip \\ {10, 0, 0, 1}) do
    post(%{build_conn() | remote_ip: ip}, ~p"/api/users/register", %{
      "email" => "burst#{n}@example.com",
      "password" => "password123"
    })
  end

  test "login: past the limit the answer is a 429 with retry-after" do
    for _ <- 1..3, do: assert(login().status == 401)

    conn = login()
    assert [retry_after] = get_resp_header(conn, "retry-after")
    assert String.to_integer(retry_after) in 1..60

    assert error_detail(conn, 429) ==
             RateLimit.retry_message(String.to_integer(retry_after))
  end

  test "the message says how long to wait, in correct English" do
    assert RateLimit.retry_message(1) == "Too many attempts. Try again in 1 second."
    assert RateLimit.retry_message(2) == "Too many attempts. Try again in 2 seconds."
    assert RateLimit.retry_message(60) == "Too many attempts. Try again in 60 seconds."
  end

  test "register: past the limit the answer is a 429 and no user is created" do
    for n <- 1..2, do: assert(register(n).status == 201)

    conn = register(3)
    assert error_detail(conn, 429) =~ "Too many attempts"
    assert get_resp_header(conn, "retry-after") != []
    assert Rephi.Accounts.get_user_by_email("burst3@example.com") == nil
  end

  test "successful requests count too" do
    Rephi.Accounts.create_user(%{"email" => "ok@example.com", "password" => "password123"})
    good = %{"email" => "ok@example.com", "password" => "password123"}

    for _ <- 1..3 do
      assert %{status: 200} =
               post(%{build_conn() | remote_ip: {10, 0, 0, 9}}, ~p"/api/users/login", good)
    end

    assert post(%{build_conn() | remote_ip: {10, 0, 0, 9}}, ~p"/api/users/login", good).status ==
             429
  end

  test "each address has its own counter" do
    for _ <- 1..3, do: login({10, 0, 0, 1})
    assert login({10, 0, 0, 1}).status == 429
    assert login({10, 0, 0, 2}).status == 401
  end

  test "each route has its own counter" do
    for _ <- 1..3, do: login()
    assert login().status == 429
    assert register(1).status == 201
  end

  test "IPv6 clients are counted per /64" do
    for n <- 1..3, do: login({0x2001, 0xDB8, 0, 0, 0, 0, 0, n})
    assert login({0x2001, 0xDB8, 0, 0, 0, 0, 0, 99}).status == 429
    assert login({0x2001, 0xDB8, 0, 1, 0, 0, 0, 1}).status == 401
  end

  test "X-Forwarded-For is ignored unless proxies are trusted" do
    for n <- 1..3, do: login({10, 0, 0, 1}, [{"x-forwarded-for", "203.0.113.#{n}"}])

    # Rotating the header does not help: the counter is the TCP peer's
    assert login({10, 0, 0, 1}, [{"x-forwarded-for", "203.0.113.50"}]).status == 429
  end

  test "with a trusted proxy, the client is the entry that proxy appended" do
    put_app_env(
      RateLimit,
      Keyword.put(Application.get_env(:rephi, RateLimit), :trusted_proxies, 1)
    )

    proxy = {10, 0, 0, 1}

    for _ <- 1..3, do: login(proxy, [{"x-forwarded-for", "198.51.100.1, 203.0.113.7"}])

    # The client controls the left part of the header, not the last entry
    assert login(proxy, [{"x-forwarded-for", "198.51.100.9, 203.0.113.7"}]).status == 429
    assert login(proxy, [{"x-forwarded-for", "203.0.113.8"}]).status == 401
  end

  test "client_address/2 falls back to the peer on a missing or invalid header" do
    conn = %{build_conn() | remote_ip: {10, 0, 0, 1}}

    assert RateLimit.client_address(conn, 1) == {10, 0, 0, 1}

    conn = put_req_header(conn, "x-forwarded-for", "not-an-ip")
    assert RateLimit.client_address(conn, 1) == {10, 0, 0, 1}
    assert RateLimit.client_address(conn, 3) == {10, 0, 0, 1}
  end

  test "disabled, nothing is throttled" do
    put_app_env(RateLimit, Keyword.put(Application.get_env(:rephi, RateLimit), :enabled, false))
    for _ <- 1..10, do: assert(login().status == 401)
  end

  test "the 429 carries CORS headers so a browser can read it" do
    for _ <- 1..3, do: login()
    conn = login({10, 0, 0, 1}, [{"origin", "http://localhost:3000"}])

    assert conn.status == 429
    assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:3000"]
    assert get_resp_header(conn, "access-control-expose-headers") == ["retry-after"]
  end

  describe "RateLimiter.hit/3" do
    test "counts within a window and denies past the limit" do
      key = {:unit, make_ref()}

      assert RateLimiter.hit(key, 2, 60_000) == {:allow, 1}
      assert RateLimiter.hit(key, 2, 60_000) == {:allow, 2}
      assert {:deny, retry_after} = RateLimiter.hit(key, 2, 60_000)
      assert retry_after in 1..60
    end

    test "a new window starts from zero" do
      key = {:unit, make_ref()}

      assert {:allow, 1} = RateLimiter.hit(key, 1, 50)
      Process.sleep(60)
      assert {:allow, 1} = RateLimiter.hit(key, 1, 50)
    end

    test "expired entries are swept" do
      key = {:unit, make_ref()}
      RateLimiter.hit(key, 1, 1)
      Process.sleep(5)

      send(RateLimiter, :sweep)
      :sys.get_state(RateLimiter)

      assert :ets.match_object(RateLimiter, {{key, :_}, :_, :_}) == []
    end
  end
end
