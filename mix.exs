defmodule Rephi.MixProject do
  use Mix.Project

  def project do
    [
      app: :rephi,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
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
      {:bandit, "~> 1.7.0"},
      {:bcrypt_elixir, "~> 3.3.2"},
      {:cors_plug, "~> 3.0.3"},
      {:dns_cluster, "~> 0.1.1"},
      {:ecto_sql, "~> 3.12.1"},
      {:ex_json_schema, "~> 0.5"},
      {:finch, "~> 0.19.0"},
      {:gettext, "~> 0.26.2"},
      {:guardian, "~> 2.3.2"},
      {:jason, "~> 1.4.4"},
      {:phoenix, "~> 1.7.21"},
      {:phoenix_ecto, "~> 4.6.4"},
      {:phoenix_live_dashboard, "~> 0.8.4"},
      {:phoenix_swagger, "~> 0.8.3"},
      {:plug, "~> 1.18"},
      {:plug_cowboy, "~> 2.7.3"},
      {:poison, "~> 3.0"},
      {:postgrex, ">= 0.20.0"},
      {:swoosh, "~> 1.19.1"},
      {:telemetry_metrics, "~> 1.1.0"},
      {:telemetry_poller, "~> 1.2.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
