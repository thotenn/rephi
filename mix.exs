defmodule Rephi.MixProject do
  use Mix.Project

  @version "0.2.0"

  def project do
    [
      app: :rephi,
      version: @version,
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader],
      test_coverage: test_coverage()
    ]
  end

  # `mix precommit` runs in the test environment, like `mix test`.
  def cli do
    [preferred_envs: [precommit: :test]]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Rephi.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bandit, "~> 1.14.1"},
      {:bcrypt_elixir, "~> 3.3.2"},
      {:cors_plug, "~> 3.0.3"},
      {:dns_cluster, "~> 0.3.1"},
      {:ecto_sql, "~> 3.14.0"},
      {:ex_doc, "~> 0.40.4", only: :dev, runtime: false, warn_if_outdated: true},
      {:finch, "~> 0.24.0"},
      {:gettext, "~> 1.0.2"},
      {:guardian, "~> 2.5.0"},
      {:jason, "~> 1.4.5"},
      {:phoenix, "~> 1.8.16"},
      {:phoenix_ecto, "~> 4.7.0"},
      {:phoenix_live_dashboard, "~> 0.9.1"},
      {:phoenix_swagger, "~> 0.8.5"},
      {:plug, "~> 1.20.3"},
      {:postgrex, "~> 0.22.4"},
      {:swoosh, "~> 1.29.3"},
      {:telemetry_metrics, "~> 1.2.0"},
      {:telemetry_poller, "~> 1.3.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  #
  #     $ mix setup       # dependencies, database, seeds and swagger.json
  #     $ mix precommit   # the checks CI runs, before you push
  #
  # `mix setup` prepares the Phoenix side only. The frontends (Node.js and
  # Yarn) are installed and built by ./setup.sh, which also checks the
  # toolchain, writes a development `.env` and then calls `mix setup`.
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "phx.swagger.generate"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      precommit: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "deps.unlock --check-unused",
        "test"
      ]
    ]
  end

  # `mix test --cover`. The modules left out are generated code (the
  # `Guardian.Plug` helpers) or only run by a Mix task (`mix phx.swagger.generate`,
  # the generators), which the coverage of the suite cannot see.
  defp test_coverage do
    [
      summary: [threshold: 90],
      ignore_modules: [
        RephiWeb.Auth.Guardian.Plug,
        Rephi.QueryCounter,
        ~r/\.(DataCase|ConnCase|ChannelCase|AuthTestHelpers)$/
      ]
    ]
  end
end
