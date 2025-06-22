defmodule Mix.Tasks.Rephi.New do
  @moduledoc """
  Creates a new Rephi project by cloning from the template repository.

      mix rephi.new PATH [--module MODULE] [--app APP]

  ## Examples

      mix rephi.new my_app
      mix rephi.new my_app --module MyApp --app my_app

  """
  use Mix.Task

  @rephi_repo "https://github.com/thotenn/rephi.git"
  @requirements []

  @impl Mix.Task
  def run(argv) do
    case parse_opts(argv) do
      {_opts, []} ->
        Mix.Tasks.Help.run(["rephi.new"])

      {opts, [path | _]} ->
        generate(path, opts)
    end
  end

  defp parse_opts(argv) do
    {opts, args, _} =
      OptionParser.parse(argv,
        strict: [
          app: :string,
          module: :string
        ]
      )

    {opts, args}
  end

  defp generate(path, opts) do
    path = Path.expand(path)
    app = opts[:app] || Path.basename(path)
    module = opts[:module] || Macro.camelize(app)

    Mix.shell().info("""
    Creating new Rephi project: #{app}
    Module: #{module}
    Path: #{path}
    """)

    # Clone the repository
    Mix.shell().info("Cloning Rephi template...")
    
    case System.cmd("git", ["clone", @rephi_repo, path]) do
      {_, 0} ->
        File.cd!(path, fn ->
          # Remove git history
          File.rm_rf!(".git")
          System.cmd("git", ["init"])
          
          # Update project files
          update_project_files(app, module)
          
          Mix.shell().info("""
          
          ✅ Project created successfully!
          
          Next steps:
          
              cd #{path}
              
              # Configure your environment
              cp .env.example .env
              # Edit .env with your database credentials
              
              # Install and setup
              mix setup
              
              # Start the server
              mix phx.server
              
          Your Rephi application is ready at http://localhost:4000
          """)
        end)
        
      {error, _} ->
        Mix.raise("Failed to clone repository: #{error}")
    end
  end

  defp update_project_files(app, module) do
    Mix.shell().info("Updating project configuration...")
    
    # Update mix.exs
    update_mix_exs(app, module)
    
    # Update application files
    update_application_files(app, module)
    
    # Update config files
    update_config_files(app, module)
    
    # Clean up
    File.rm_rf!("installer")
    File.rm("LICENSE")
    File.rm("CHANGELOG.md")
    
    # Create new README
    create_readme(app, module)
  end

  defp update_mix_exs(app, module) do
    content = File.read!("mix.exs")
    
    new_content = content
    |> String.replace("defmodule Rephi.MixProject", "defmodule #{module}.MixProject")
    |> String.replace("app: :rephi", "app: :#{app}")
    |> String.replace("mod: {Rephi.Application", "mod: {#{module}.Application")
    |> String.replace(~r/@version ".*"/, "@version \"0.1.0\"")
    |> String.replace(~r/@source_url ".*"/, "@source_url \"https://github.com/yourusername/#{app}\"")
    |> String.replace(~r/@manteiners \[.*\]/, "@manteiners [\"Your Name\"]")
    |> String.replace(~r/name: ".*"/, "name: \"#{module}\"")
    |> String.replace(~r/description\(\)/, "\"#{module} application built with Rephi\"")
    
    # Remove hex package info
    new_content = Regex.replace(~r/# Hex.*?source_url: @source_url,?\n/ms, new_content, "")
    new_content = Regex.replace(~r/defp package.*?end\n/ms, new_content, "")
    new_content = Regex.replace(~r/defp docs.*?end\n/ms, new_content, "")
    
    File.write!("mix.exs", new_content)
  end

  defp update_application_files(app, module) do
    # Update all .ex and .exs files
    Path.wildcard("{lib,test,config}/**/*.{ex,exs}")
    |> Enum.each(fn file ->
      if File.exists?(file) do
        content = File.read!(file)
        new_content = content
        |> String.replace("Rephi", module)
        |> String.replace("rephi", app)
        |> String.replace("REPHI", String.upcase(app))
        
        File.write!(file, new_content)
      end
    end)
    
    # Rename directories
    if File.exists?("lib/rephi") do
      File.rename!("lib/rephi", "lib/#{app}")
    end
    
    if File.exists?("lib/rephi_web") do
      File.rename!("lib/rephi_web", "lib/#{app}_web")
    end
    
    if File.exists?("test/rephi") do
      File.rename!("test/rephi", "test/#{app}")
    end
    
    if File.exists?("test/rephi_web") do
      File.rename!("test/rephi_web", "test/#{app}_web")
    end
  end

  defp update_config_files(app, module) do
    # Update endpoint references in config
    Path.wildcard("config/*.exs")
    |> Enum.each(fn file ->
      content = File.read!(file)
      new_content = content
      |> String.replace("RephiWeb.Endpoint", "#{module}Web.Endpoint")
      |> String.replace("Rephi.Repo", "#{module}.Repo")
      |> String.replace("Rephi.Mailer", "#{module}.Mailer")
      |> String.replace("rephi:", "#{app}:")
      |> String.replace("ecto_repos: [Rephi.Repo]", "ecto_repos: [#{module}.Repo]")
      
      File.write!(file, new_content)
    end)
  end

  defp create_readme(_app, module) do
    readme = """
    # #{module}

    #{module} is built with Rephi - A Phoenix boilerplate with JWT auth, RBAC, WebSocket support, and multi-frontend architecture.

    ## Getting Started

    1. **Configure environment**:
       ```bash
       cp .env.example .env
       # Edit .env with your configuration
       ```

    2. **Install and setup**:
       ```bash
       mix setup
       ```

    3. **Start Phoenix server**:
       ```bash
       mix phx.server
       ```

    Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

    ## Features

    - JWT Authentication
    - Role-Based Access Control (RBAC)
    - WebSocket support
    - Multi-frontend architecture
    - API documentation with Swagger
    - CSRF protection for SPAs

    ## Default Credentials

    - Email: admin@admin.com
    - Password: password123!!

    ## Learn more

    - Rephi: https://github.com/thotenn/rephi
    - Phoenix: https://www.phoenixframework.org/
    - Phoenix Guides: https://hexdocs.pm/phoenix/overview.html
    """
    
    File.write!("README.md", readme)
  end
end