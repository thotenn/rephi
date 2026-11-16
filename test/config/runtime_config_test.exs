defmodule Rephi.RuntimeConfigTest do
  @moduledoc """
  Evaluates config/runtime.exs as production would (SEC-02, SEC-14, SEC-15,
  SEC-20, API-12) and checks `.env.example` (SEC-03, API-15).
  """
  use ExUnit.Case, async: false

  @runtime Path.expand("../../config/runtime.exs", __DIR__)
  @env_example Path.expand("../../.env.example", __DIR__)

  @required %{
    "DATABASE_URL" => "ecto://user:pass@localhost/rephi_prod",
    "SECRET_KEY_BASE" => String.duplicate("s", 64),
    "GUARDIAN_SECRET_KEY" => String.duplicate("g", 64),
    "PHX_HOST" => "api.example.com"
  }

  @optional ~w(PHX_SERVER PORT POOL_SIZE ECTO_IPV6 DNS_CLUSTER_QUERY TOKEN_TTL_SECONDS
               CORS_ORIGINS CHECK_ORIGIN FORCE_SSL SWAGGER_ENABLED RATE_LIMIT_ENABLED
               RATE_LIMIT_LOGIN_MAX RATE_LIMIT_REGISTER_MAX RATE_LIMIT_WINDOW_SECONDS
               RATE_LIMIT_TRUSTED_PROXIES)

  setup do
    names = Map.keys(@required) ++ @optional
    saved = Map.new(names, &{&1, System.get_env(&1)})
    Enum.each(names, &System.delete_env/1)

    on_exit(fn ->
      Enum.each(saved, fn
        {name, nil} -> System.delete_env(name)
        {name, value} -> System.put_env(name, value)
      end)
    end)
  end

  defp prod_config(env) do
    Enum.each(Map.keys(@required) ++ @optional, &System.delete_env/1)
    System.put_env(env)
    Config.Reader.read!(@runtime, env: :prod, target: :host)
  end

  defp endpoint(config), do: config[:rephi][RephiWeb.Endpoint]

  for name <- ~w(DATABASE_URL SECRET_KEY_BASE GUARDIAN_SECRET_KEY PHX_HOST) do
    test "production refuses to boot without #{name}" do
      env = Map.delete(@required, unquote(name))

      assert_raise RuntimeError, ~r/environment variable #{unquote(name)} is missing/, fn ->
        prod_config(env)
      end
    end

    test "an empty #{name} counts as missing" do
      env = Map.put(@required, unquote(name), " ")

      assert_raise RuntimeError, ~r/#{unquote(name)} is missing/, fn -> prod_config(env) end
    end
  end

  test "a GUARDIAN_SECRET_KEY under 32 bytes is refused" do
    assert_raise RuntimeError, ~r/GUARDIAN_SECRET_KEY is too short/, fn ->
      prod_config(%{@required | "GUARDIAN_SECRET_KEY" => "short"})
    end
  end

  test "with the required variables: secrets, host, HTTPS and origin check" do
    config = prod_config(@required)

    assert config[:rephi][RephiWeb.Auth.Guardian][:secret_key] == @required["GUARDIAN_SECRET_KEY"]
    assert endpoint(config)[:url] == [host: "api.example.com", port: 443, scheme: "https"]
    assert endpoint(config)[:check_origin] == ["//api.example.com"]

    force_ssl = config[:rephi][:force_ssl]
    assert force_ssl[:rewrite_on] == [:x_forwarded_proto]
    assert force_ssl[:hsts] == true
    assert "/api/health" in force_ssl[:exclude][:paths]

    # Nothing in runtime.exs turns these on by default
    refute Keyword.has_key?(config[:rephi], :swagger_enabled)
    refute Keyword.has_key?(config[:rephi], :cors_origins)
  end

  test "CORS_ORIGINS feeds CORS and the WebSocket origin check" do
    config =
      prod_config(
        Map.put(
          @required,
          "CORS_ORIGINS",
          " https://app.example.com , https://*.example.pages.dev,"
        )
      )

    assert config[:rephi][:cors_origins] == [
             "https://app.example.com",
             "https://*.example.pages.dev"
           ]

    assert endpoint(config)[:check_origin] ==
             ["//api.example.com", "https://app.example.com", "https://*.example.pages.dev"]
  end

  test "CHECK_ORIGIN overrides the origin check" do
    assert endpoint(prod_config(Map.put(@required, "CHECK_ORIGIN", "false")))[:check_origin] ==
             false

    assert endpoint(prod_config(Map.put(@required, "CHECK_ORIGIN", "true")))[:check_origin] ==
             true

    assert endpoint(prod_config(Map.put(@required, "CHECK_ORIGIN", "https://a.example.com")))[
             :check_origin
           ] == ["https://a.example.com"]
  end

  test "FORCE_SSL=false turns the redirect off" do
    assert prod_config(Map.put(@required, "FORCE_SSL", "false"))[:rephi][:force_ssl] == false
  end

  test "SWAGGER_ENABLED turns the documentation on" do
    assert prod_config(Map.put(@required, "SWAGGER_ENABLED", "true"))[:rephi][:swagger_enabled] ==
             true
  end

  test "TOKEN_TTL_SECONDS and the rate limits" do
    config =
      prod_config(
        Map.merge(@required, %{
          "TOKEN_TTL_SECONDS" => "3600",
          "RATE_LIMIT_LOGIN_MAX" => "20",
          "RATE_LIMIT_WINDOW_SECONDS" => "30",
          "RATE_LIMIT_TRUSTED_PROXIES" => "1"
        })
      )

    assert config[:rephi][RephiWeb.Auth.Guardian][:ttl] == {3600, :seconds}

    rate_limit = config[:rephi][RephiWeb.Plugs.RateLimit]
    assert rate_limit[:login] == [limit: 20, window_seconds: 30]
    assert rate_limit[:register] == [window_seconds: 30]
    assert rate_limit[:trusted_proxies] == 1
  end

  test "malformed numbers and flags stop the boot with the variable's name" do
    assert_raise RuntimeError, ~r/TOKEN_TTL_SECONDS must be an integer/, fn ->
      prod_config(Map.put(@required, "TOKEN_TTL_SECONDS", "1h"))
    end

    assert_raise RuntimeError, ~r/FORCE_SSL must be true or false/, fn ->
      prod_config(Map.put(@required, "FORCE_SSL", "maybe"))
    end
  end

  describe ".env.example" do
    setup do
      {:ok, lines: @env_example |> File.read!() |> String.split("\n")}
    end

    test "sets no variable: every assignment is commented out", %{lines: lines} do
      assert Enum.filter(lines, &(&1 =~ ~r/\A\s*(export\s+)?[A-Z_]+=/)) == []
    end

    test "carries no usable secret", %{lines: lines} do
      for name <- ~w(SECRET_KEY_BASE GUARDIAN_SECRET_KEY ADMIN_PASSWORD) do
        assigned = Enum.filter(lines, &(&1 =~ ~r/\A#\s*#{name}=/))
        assert assigned != [], "#{name} is not documented"

        assert Enum.all?(assigned, &(&1 =~ ~r/=\s*\z/)),
               "#{name} has a value: #{inspect(assigned)}"
      end

      refute Enum.any?(lines, &(&1 =~ ~r/=your-/))
    end

    test "documents only variables something reads, and not MIX_ENV or PHX_SERVER", %{
      lines: lines
    } do
      documented =
        for line <- lines, [_, name] <- [Regex.run(~r/\A#\s*([A-Z][A-Z0-9_]+)=/, line)], do: name

      sources =
        ["config/*.exs", "lib/**/*.ex"]
        |> Enum.flat_map(&Path.wildcard(Path.expand("../../" <> &1, __DIR__)))
        |> Enum.map_join("\n", &File.read!/1)

      for name <- documented do
        assert sources =~ ~s("#{name}"), "#{name} is documented but nothing reads it"
      end

      refute "MIX_ENV" in documented
      refute "PHX_SERVER" in documented
    end
  end
end
