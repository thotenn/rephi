defmodule Mix.Tasks.Rephi.New do
  @moduledoc """
  Creates a new Rephi application.

  It expects the path of the project as an argument.

      mix rephi.new PATH [--module MODULE] [--app APP]

  A project at the given PATH will be created. The application name and module
  name will be retrieved from the path, unless `--module` or `--app` is given.

  ## Options

    * `--app` - the name of the OTP application

    * `--module` - the name of the base module in the generated skeleton

    * `--database` - specify the database adapter for Ecto. One of:

        * `postgres` - via https://github.com/elixir-ecto/postgrex (default)
        * `mysql` - via https://github.com/elixir-ecto/myxql
        * `mssql` - via https://github.com/livehelpnow/tds
        * `sqlite3` - via https://github.com/elixir-sqlite/ecto_sqlite3

      Please check the driver docs for more information. Defaults to "postgres".

    * `--no-frontend` - do not generate frontend applications

    * `--binary-id` - use `binary_id` as primary key type in Ecto schemas

  ## Examples

      mix rephi.new hello_world

  Is equivalent to:

      mix rephi.new hello_world --module HelloWorld

  """

  use Mix.Task

  @version Mix.Project.config()[:version]
  @requirements ["app.new"]

  @impl Mix.Task
  def run(argv) do
    case parse_opts(argv) do
      {_opts, []} ->
        Mix.Tasks.Help.run(["rephi.new"])

      {opts, [base_path | _]} ->
        generate(base_path, opts)
    end
  end

  defp parse_opts(argv) do
    {opts, args, _} =
      OptionParser.parse(argv,
        strict: [
          app: :string,
          module: :string,
          database: :string,
          binary_id: :boolean,
          no_frontend: :boolean
        ]
      )

    {opts, args}
  end

  defp generate(base_path, opts) do
    base_path = Path.expand(base_path)
    app = opts[:app] || Path.basename(base_path)
    module = opts[:module] || Macro.camelize(app)
    
    unless File.exists?(base_path) do
      File.mkdir_p!(base_path)
    end
    
    File.cd!(base_path, fn ->
      Mix.shell().info("* creating new Rephi application #{app}")
      
      # Generate Phoenix app
      Mix.Tasks.Phx.New.run([
        ".",
        "--app", app,
        "--module", module,
        "--database", opts[:database] || "postgres",
        "--no-html",
        "--no-assets",
        "--no-mailer"
      ] ++ if opts[:binary_id], do: ["--binary-id"], else: [])
      
      # Copy Rephi-specific files
      copy_rephi_files(module, app)
      
      # Generate frontend apps unless disabled
      unless opts[:no_frontend] do
        generate_frontend_apps()
      end
      
      Mix.shell().info("""

      Your Rephi application is ready!

      To get started:
          cd #{base_path}
          mix setup

      Start your Phoenix server:
          mix phx.server

      You can also run it inside IEx:
          iex -S mix phx.server
      """)
    end)
  end

  defp copy_rephi_files(module, app) do
    source_dir = Application.app_dir(:rephi, "priv/templates/rephi.new")
    
    # Copy authorization context
    copy_file(
      Path.join(source_dir, "authorization.ex"),
      "lib/#{app}/authorization.ex",
      module: module,
      app: app
    )
    
    # Copy auth controllers and plugs
    copy_file(
      Path.join(source_dir, "auth_controller.ex"),
      "lib/#{app}_web/controllers/auth_controller.ex",
      module: module,
      app: app
    )
    
    copy_file(
      Path.join(source_dir, "authorization_plug.ex"),
      "lib/#{app}_web/auth/authorization_plug.ex",
      module: module,
      app: app
    )
    
    # Copy RBAC controllers
    copy_file(
      Path.join(source_dir, "role_controller.ex"),
      "lib/#{app}_web/controllers/role_controller.ex",
      module: module,
      app: app
    )
    
    copy_file(
      Path.join(source_dir, "permission_controller.ex"),
      "lib/#{app}_web/controllers/permission_controller.ex",
      module: module,
      app: app
    )
    
    # Update router with Rephi routes
    update_router(module, app)
    
    # Add Rephi dependencies
    update_mix_exs(app)
  end

  defp copy_file(source, target, bindings) do
    content = EEx.eval_file(source, bindings)
    File.mkdir_p!(Path.dirname(target))
    File.write!(target, content)
  end

  defp update_router(module, app) do
    # Add Rephi-specific routes to the router
    router_path = "lib/#{app}_web/router.ex"
    # Implementation to inject routes
  end

  defp update_mix_exs(app) do
    # Add Rephi-specific dependencies
    mix_path = "mix.exs"
    # Implementation to add dependencies
  end

  defp generate_frontend_apps do
    Mix.shell().info("* generating frontend applications")
    
    File.mkdir_p!("apps")
    
    # Create shared components directory
    File.mkdir_p!("apps/shared")
    
    # Generate each frontend app
    ~w(dashboard admin ecommerce landing)
    |> Enum.each(fn app ->
      Mix.shell().info("  * creating #{app} frontend")
      File.mkdir_p!("apps/#{app}")
      # Copy frontend template files
    end)
  end
end