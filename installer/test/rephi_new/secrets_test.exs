defmodule RephiNew.SecretsTest do
  use ExUnit.Case, async: true

  alias RephiNew.Secrets

  @dev """
  config :app, AppWeb.Endpoint,
    secret_key_base:
      System.get_env(
        "SECRET_KEY_BASE",
        "dev-secret-key-base"
      ),
    watchers: []

  config :app, AppWeb.Auth.Guardian,
    secret_key: "dev-guardian"
  """

  @test """
  config :app, AppWeb.Endpoint,
    secret_key_base: "test-secret-key-base",
    server: false

  config :app, AppWeb.Auth.Guardian, secret_key: "test-guardian"
  """

  @config ~s{config :app, AppWeb.Endpoint, live_view: [signing_salt: "lv-salt"]\n}

  @endpoint ~s{  @session_options [store: :cookie, signing_salt: "cookie-salt"]\n}

  @runtime """
  config :app, AppWeb.Endpoint, secret_key_base: secret_key_base
  config :app, AppWeb.Auth.Guardian, secret_key: guardian_secret
  """

  defp files do
    [
      {"config/dev.exs", @dev},
      {"config/test.exs", @test},
      {"config/config.exs", @config},
      {"config/runtime.exs", @runtime},
      {"lib/app_web/endpoint.ex", @endpoint}
    ]
  end

  test "replaces every committed secret and salt with a new random value" do
    assert {:ok, files} = Secrets.regenerate(files())
    all = Enum.map_join(files, &elem(&1, 1))

    for old <-
          ~w(dev-secret-key-base dev-guardian test-secret-key-base test-guardian lv-salt cookie-salt) do
      refute all =~ old
    end

    {_, dev} = List.keyfind(files, "config/dev.exs", 0)
    assert [_, key] = Regex.run(~r/"SECRET_KEY_BASE",\s*"([^"]+)"/, dev)
    assert byte_size(key) == 64

    assert [_, salt] =
             Regex.run(~r/signing_salt: "([^"]+)"/, Map.new(files)["lib/app_web/endpoint.ex"])

    assert byte_size(salt) == 8

    # Values read from the environment at runtime are not secrets to replace.
    assert {"config/runtime.exs", @runtime} in files
  end

  test "two projects never get the same values" do
    {:ok, a} = Secrets.regenerate(files())
    {:ok, b} = Secrets.regenerate(files())
    for {{path, one}, {path, other}} <- Enum.zip(a, b), one != @runtime, do: assert(one != other)
  end

  test "refuses a template that does not have exactly the expected secrets" do
    files = List.keydelete(files(), "config/test.exs", 0)
    assert {:error, message} = Secrets.regenerate(files)
    assert message =~ "secret_key_base: expected 2, found 1"
    assert message =~ "guardian_secret_key: expected 2, found 1"
  end

  test "files_in/1 picks the configuration and the endpoint" do
    paths = ~w(config/dev.exs config/runtime.exs lib/app_web/endpoint.ex lib/app/repo.ex
               lib/app_web/plugs/endpoint.ex test/app_web/endpoint.ex mix.exs)

    assert Secrets.files_in(paths) ==
             ~w(config/dev.exs config/runtime.exs lib/app_web/endpoint.ex)
  end

  test "generate/1 gives keys of 64 characters and salts of 8" do
    assert byte_size(Secrets.generate(:secret_key_base)) == 64
    assert byte_size(Secrets.generate(:signing_salt)) == 8
    assert Secrets.generate(:signing_salt) =~ ~r/\A[A-Za-z0-9+\/]{8}\z/
  end
end
