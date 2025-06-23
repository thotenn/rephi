defmodule Rephi.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/thotenn/rephi"
  @maintainers ["thotenn"]

  def project do
    [
      app: :rephi,
      version: @version,
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),

      # Hex
      name: "Rephi",
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url
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
      {:ex_doc, "~> 0.34", only: :dev, runtime: false, warn_if_outdated: true},
      {:ex_json_schema, "~> 0.5"},
      {:finch, "~> 0.19.0"},
      {:gettext, "~> 0.26.2"},
      {:guardian, "~> 2.3.2"},
      {:jason, "~> 1.4.4"},
      {:phoenix, "~> 1.7.21"},
      {:phoenix_ecto, "~> 4.6.4"},
      {:phoenix_live_dashboard, "~> 0.8.7"},
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
      setup: ["deps.get", "ecto.setup", "frontends.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "frontends.build": &build_frontends/1,
      "frontends.clean": &clean_frontends/1
    ]
  end

  defp build_frontends(_) do
    apps = ["dashboard", "admin", "ecommerce", "landing"]

    # Ensure priv/static directories exist
    Enum.each(apps, fn app ->
      File.mkdir_p!("priv/static/#{app}")
    end)

    # Build each frontend app that exists
    Enum.each(apps, fn app ->
      app_path = "apps/#{app}"

      if File.exists?(app_path) do
        Mix.shell().info("Building #{app}...")

        # Install dependencies
        case System.cmd("npm", ["install"], cd: app_path, stderr_to_stdout: true) do
          {_output, 0} ->
            Mix.shell().info("✓ Dependencies installed for #{app}")

            # Build the app
            case System.cmd("npm", ["run", "build"], cd: app_path, stderr_to_stdout: true) do
              {_output, 0} ->
                # Copy build files to priv/static
                source = Path.join(app_path, "dist")
                dest = "priv/static/#{app}"

                if File.exists?(source) do
                  File.cp_r!(source, dest)
                  Mix.shell().info("✓ #{app} built successfully")
                else
                  Mix.shell().error("Build directory not found for #{app}")
                end

              {output, exit_code} ->
                Mix.shell().error("Failed to build #{app}: #{output}")
                Mix.raise("Frontend build failed with exit code #{exit_code}")
            end

          {output, exit_code} ->
            Mix.shell().error("Failed to install dependencies for #{app}: #{output}")
            Mix.raise("npm install failed with exit code #{exit_code}")
        end
      else
        Mix.shell().info("Skipping #{app} (not found)")
      end
    end)

    Mix.shell().info("Frontend builds completed!")
  end

  defp clean_frontends(_) do
    Mix.shell().info("Cleaning frontend builds...")
    apps = ["dashboard", "admin", "ecommerce", "landing"]

    Enum.each(apps, fn app ->
      File.rm_rf("priv/static/#{app}")
    end)

    Mix.shell().info("Frontend builds cleaned!")
  end

  defp description do
    "Phoenix framework with JWT auth, RBAC authorization, WebSocket support, and multiple React frontends architecture"
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      maintainers: @maintainers,
      files: ~w(lib priv/repo config mix.exs README* LICENSE* CHANGELOG*),
      exclude_patterns: [
        "priv/static/dashboard",
        "priv/static/admin",
        "priv/static/ecommerce",
        "priv/static/landing"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      source_ref: "v#{@version}",
      source_url: @source_url,
      formatters: ["html"]
    ]
  end
end
