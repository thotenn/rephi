defmodule Mix.Tasks.Rephi.New do
  @shortdoc "Creates a new Rephi project"

  @moduledoc """
  Creates a new project from the Rephi template.

      mix rephi.new PATH [--app APP] [--module MODULE] [--no-install] [--no-git]

  The project is created in `PATH` (which must not exist), named after the last
  segment of the path unless `--app` says otherwise.

  ## Examples

      mix rephi.new acme_hub
      mix rephi.new ~/code/hub --app acme_hub --module AcmeHub

  ## Options

    * `--app` - the OTP application name (`acme_hub`): lowercase letters,
      digits and underscores, starting with a letter. Defaults to the last
      segment of `PATH`.
    * `--module` - the base module name (`AcmeHub`). Defaults to the camelized
      application name.
    * `--no-install` - do not run `mix deps.get` and `mix format` in the new
      project. The generated code is formatted for the template's names, so
      run `mix format` after fetching the dependencies yourself.
    * `--no-git` - do not create a Git repository with an initial commit.
    * `--from` - where to take the template from: a Git URL or the path of a
      local clone (its committed `HEAD`). Defaults to #{inspect("https://github.com/thotenn/rephi.git")}.
    * `--branch` - the branch or tag of the template to use (default: the
      repository's default branch).

  ## What it does

  It clones the template into a temporary directory next to `PATH`, renames
  the application and its modules (`rephi` -> APP, `Rephi` -> MODULE, in code,
  configuration, seeds, migrations, tests and docs; file names too), gives the
  project its own secrets and salts, writes a README, fetches the
  dependencies, formats the code, creates the Git repository with an initial
  commit and only then moves the result to `PATH`. If any step fails, nothing
  is left behind.

  Kept as they are: `mix rephi.gen.frontend` (the generator keeps its name,
  like `mix phx.gen.*`), the npm names of the frontend workspaces and URLs.
  See `RephiNew.Rename`.

  Next, inside the project, `./setup.sh` checks the toolchain, writes a
  development `.env` with fresh secrets, creates and seeds the database and
  builds the frontends.
  """

  use Mix.Task

  alias RephiNew.{Rename, Secrets}

  @default_source "https://github.com/thotenn/rephi.git"

  @switches [
    app: :string,
    module: :string,
    from: :string,
    branch: :string,
    install: :boolean,
    git: :boolean
  ]

  # Files and directories of the template that a project does not get.
  @drop ~w(.git installer LICENSE CHANGELOG.md)

  # Directories copied as they are: the frontends (npm names are kept, see
  # RephiNew.Rename), dependencies and build output.
  @verbatim_dirs ~w(apps packages node_modules deps _build .yarn priv/static)

  @impl Mix.Task
  def run(argv) do
    case OptionParser.parse(argv, strict: @switches) do
      {_opts, [], []} ->
        Mix.Tasks.Help.run(["rephi.new"])

      {opts, [path], []} ->
        generate(path, opts)

      {_opts, _args, [{switch, _} | _]} ->
        fail("Unknown or invalid option #{switch}. See: mix help rephi.new")

      {_opts, _args, []} ->
        fail("Expected a single PATH. See: mix help rephi.new")
    end
  end

  defp fail(message) do
    Mix.shell().error(message)
    exit({:shutdown, 1})
  end

  defp generate(path, opts) do
    path = Path.expand(path)
    app = opts[:app] || Path.basename(path)
    module = opts[:module] || Macro.camelize(app)
    names = %{app: app, module: module}

    with :ok <- Rename.validate_app(app),
         :ok <- Rename.validate_module(module),
         :ok <- check_path(path),
         {:ok, git} <- find_git() do
      parent = Path.dirname(path)
      File.mkdir_p!(parent)
      suffix = "#{Path.basename(path)}.rephi-new-#{System.unique_integer([:positive])}"
      clone_dir = Path.join(parent, ".#{suffix}.clone")
      build_dir = Path.join(parent, ".#{suffix}")

      try do
        with :ok <- clone(git, opts[:from] || @default_source, opts[:branch], clone_dir),
             :ok <- build(clone_dir, build_dir, names),
             :ok <- install(build_dir, Keyword.get(opts, :install, true)),
             :ok <- init_git(git, build_dir, Keyword.get(opts, :git, true)),
             :ok <- File.rename(build_dir, path) do
          Mix.shell().info(next_steps(path, app, Keyword.get(opts, :install, true)))
        else
          {:error, message} when is_binary(message) -> fail(message)
          {:error, reason} -> fail("Could not create #{path}: #{inspect(reason)}")
        end
      after
        File.rm_rf(clone_dir)
        File.rm_rf(build_dir)
      end
    else
      {:error, message} -> fail(message)
    end
  end

  defp check_path(path) do
    if File.exists?(path) do
      {:error, "#{path} already exists. Choose another path or remove it first."}
    else
      :ok
    end
  end

  defp find_git do
    case System.find_executable("git") do
      nil -> {:error, "Git is required to fetch the template and was not found in the PATH."}
      git -> {:ok, git}
    end
  end

  defp clone(git, source, branch, dir) do
    Mix.shell().info([:green, "* fetching ", :reset, "the template from #{source}"])

    local? = File.dir?(source)
    source = if local?, do: Path.expand(source), else: source

    args =
      ["clone", "--quiet"] ++
        if(local?, do: [], else: ["--depth", "1"]) ++
        if(branch, do: ["--branch", branch], else: []) ++ [source, dir]

    case System.cmd(git, args, stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, _} -> {:error, "Could not fetch the template from #{source}:\n#{output}"}
    end
  end

  ## Building the project

  defp build(source, target, names) do
    files =
      source
      |> list_files()
      |> Enum.reject(&dropped?/1)

    renamed =
      Enum.map(files, fn file ->
        contents = File.read!(Path.join(source, file))

        if verbatim?(file) or not text?(contents) do
          {file, contents}
        else
          {Rename.path(file, names), Rename.text(contents, names)}
        end
      end)

    secret_files = MapSet.new(Secrets.files_in(Enum.map(renamed, &elem(&1, 0))))
    {with_secrets, others} = Enum.split_with(renamed, &(elem(&1, 0) in secret_files))

    with {:ok, with_secrets} <- Secrets.regenerate(with_secrets) do
      files = others ++ with_secrets ++ [{"README.md", readme(names)}]

      Enum.each(files, fn {file, contents} ->
        destination = Path.join(target, file)
        File.mkdir_p!(Path.dirname(destination))
        File.write!(destination, contents)
        copy_mode(Path.join(source, file), destination)
      end)

      # Executable scripts keep their mode under their new names too.
      for {file, _} <- files, file == "setup.sh" do
        File.chmod!(Path.join(target, file), 0o755)
      end

      Mix.shell().info([:green, "* created ", :reset, "#{length(files)} files"])
      :ok
    end
  end

  defp copy_mode(source, destination) do
    case File.stat(source) do
      {:ok, %{mode: mode}} -> File.chmod(destination, mode)
      _ -> :ok
    end
  end

  # Relative paths of every regular file under `dir`.
  defp list_files(dir) do
    dir
    |> Path.join("**")
    |> Path.wildcard(match_dot: true)
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&Path.relative_to(&1, dir))
    |> Enum.sort()
  end

  defp dropped?(file) do
    [first | _] = Path.split(file)
    first in @drop or file == "README.md"
  end

  defp verbatim?(file) do
    Enum.any?(@verbatim_dirs, &(file == &1 or String.starts_with?(file, &1 <> "/"))) or
      Path.basename(file) in ~w(package.json yarn.lock .yarnrc.yml) or
      Path.extname(file) in ~w(.js .mjs .cjs .ts .tsx .json .lock)
  end

  defp text?(contents), do: String.valid?(contents) and not String.contains?(contents, <<0>>)

  ## Dependencies, formatting and Git

  defp install(_dir, false), do: :ok

  defp install(dir, true) do
    with :ok <- cmd("mix", ["deps.get"], dir, "fetching dependencies"),
         :ok <- cmd("mix", ["format"], dir, "formatting the code") do
      :ok
    end
  end

  defp init_git(_git, _dir, false), do: :ok

  defp init_git(git, dir, true) do
    with :ok <-
           cmd(
             git,
             ["init", "--quiet", "--initial-branch=main"],
             dir,
             "creating a Git repository"
           ),
         :ok <- cmd(git, ["add", "--all"], dir, nil) do
      case System.cmd(git, ["commit", "--quiet", "-m", "Initial commit (mix rephi.new)"],
             cd: dir,
             stderr_to_stdout: true
           ) do
        {_, 0} ->
          :ok

        {output, _} ->
          # Usually a missing user.name / user.email: the files stay staged.
          Mix.shell().error(
            "The initial commit could not be created; the files are staged.\n#{output}"
          )

          :ok
      end
    end
  end

  defp cmd(command, args, dir, label) do
    if label, do: Mix.shell().info([:green, "* running ", :reset, label])
    executable = System.find_executable(command) || command

    # A clean environment for the new project's own Mix.
    env = [{"MIX_ENV", nil}, {"MIX_EXS", nil}, {"MIX_BUILD_PATH", nil}, {"MIX_DEPS_PATH", nil}]

    case System.cmd(executable, args, cd: dir, stderr_to_stdout: true, env: env) do
      {_, 0} ->
        :ok

      {output, status} ->
        {:error, "`#{command} #{Enum.join(args, " ")}` failed (#{status}):\n#{output}"}
    end
  rescue
    error in ErlangError -> {:error, "Could not run #{command}: #{Exception.message(error)}"}
  end

  ## Output

  defp readme(%{app: app, module: module}) do
    """
    # #{module}

    A Phoenix API with JWT authentication, role-based access control, real-time
    notifications and React frontends, generated from
    [Rephi](https://github.com/thotenn/rephi).

    ## Getting started

    Requirements: Elixir and Erlang/OTP (see `.tool-versions`), Node.js >= 22.22
    with Yarn 4 through Corepack, and PostgreSQL.

    ```bash
    ./setup.sh          # checks the toolchain, writes .env, database + seeds, frontends
    mix phx.server
    ```

    Then open:

    - http://localhost:4000/app/example/ - the example frontend (log in with the
      development administrator that `./setup.sh` prints)
    - http://localhost:4000/api/swagger - the API documentation
    - http://localhost:4000/api/health - liveness check

    The development database is `#{app}_dev`; `.env.example` lists every setting.

    ## Useful commands

    ```bash
    mix setup                         # Phoenix only: deps, database, seeds, swagger.json
    mix precommit                     # format check, warnings, unused deps, tests
    mix test
    yarn shared:build && yarn build   # build the frontends into priv/static/apps
    mix rephi.gen.frontend NAME       # a new frontend app (see `mix help rephi.gen.frontend`)
    ```
    """
  end

  defp next_steps(path, app, installed?) do
    format_step =
      if installed?, do: "", else: "    mix deps.get && mix format\n"

    """

    Your project #{app} was created in #{path}.

    Next steps:

        cd #{Path.relative_to_cwd(path)}
    #{format_step}    ./setup.sh
        mix phx.server

    Then open http://localhost:4000/app/example/ and http://localhost:4000/api/swagger
    """
  end
end
