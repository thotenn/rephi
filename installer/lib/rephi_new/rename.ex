defmodule RephiNew.Rename do
  @moduledoc """
  Renames the template (`rephi` / `Rephi`) to the new project's names.

  The template's names are replaced as whole names, in one pass, so a project
  whose own name contains the template's (`morephi`) is never renamed twice.
  A name is whole when it is not glued to other letters or digits: `rephi_web`,
  `_rephi_key` and `:rephi` are renamed, `morephi` is not. An underscore is a
  separator for the lowercase name and part of the name for the module name.

  Left as they are, on purpose:

    * URLs (`https://github.com/thotenn/rephi`): they point at the template;
    * the Mix task namespace: `mix rephi.gen.frontend` keeps its name in every
      project, the way `mix phx.gen.*` does (`Mix.Tasks.Rephi.*`,
      `rephi.gen.*`, `rephi.new`);
    * npm names: the private Yarn workspaces (`@rephi/shared-components`,
      `rephi-example`, ...) and the `"rephi"` field of an app's package.json
      are internal to the monorepo and are never published, so renaming them
      would only mean rewriting every import of the frontends.
  """

  @url ~r{https?://[^\s"'`<>)\]]+}

  @doc """
  Replaces the template's names in `text`.

  `names` is a map with `:app` (`"acme_hub"`) and `:module` (`"AcmeHub"`).
  """
  @spec text(String.t(), %{app: String.t(), module: String.t()}) :: String.t()
  def text(text, %{app: app, module: module}) do
    @url
    |> Regex.split(text, include_captures: true, trim: false)
    |> Enum.map_join(fn part ->
      if part =~ ~r/\A#{@url.source}\z/, do: part, else: replace(part, app, module)
    end)
  end

  defp replace(text, app, module) do
    Regex.replace(name_regex(), text, fn
      "Rephi" -> module
      "rephi" -> app
      "REPHI" -> String.upcase(app)
    end)
  end

  # One alternation, so a replacement is never matched again.
  #
  #   * `Rephi` not after a letter, digit, `_` or `.` (`Mix.Tasks.Rephi`), and
  #     not followed by a lowercase letter or digit (`RephiWeb` is renamed);
  #   * `rephi` not glued to letters or digits, nor part of an npm name
  #     (`@rephi/`, `rephi-example`), a Mix task (`rephi.gen.`, `rephi.new`),
  #     the `"rephi"` field of a package.json or the frontends' `~/lib/rephi`
  #     module;
  #   * `REPHI` (`REPHI_SOMETHING`).
  defp name_regex do
    ~r/(?<![A-Za-z0-9_.])Rephi(?![a-z0-9])(?!\.(?:Gen|New)\b)|(?<![A-Za-z0-9@.-])(?<!~\/lib\/)rephi(?![A-Za-z0-9-])(?!\.(?:gen|new)\b)(?!":)(?!\.copyToPhoenix)|(?<![A-Za-z0-9])REPHI(?![A-Z0-9])/
  end

  @doc """
  Renames every segment of a relative `path` (`lib/rephi_web/endpoint.ex` ->
  `lib/acme_hub_web/endpoint.ex`). Mix task files (`rephi.gen.frontend.ex`)
  keep their names.
  """
  @spec path(Path.t(), %{app: String.t(), module: String.t()}) :: Path.t()
  def path(path, names) do
    path
    |> Path.split()
    |> Enum.map(&text(&1, names))
    |> Path.join()
  end

  @app_pattern ~r/\A[a-z][a-z0-9_]*\z/
  @module_pattern ~r/\A[A-Z][A-Za-z0-9]*(\.[A-Z][A-Za-z0-9]*)*\z/

  # Applications that a project cannot be named after: the ones of Erlang and
  # Elixir it starts, and the dependencies of the template.
  @reserved_apps ~w(
    elixir eex ex_unit iex logger mix kernel stdlib crypto ssl public_key
    runtime_tools inets compiler
    bandit bcrypt_elixir cors_plug dns_cluster ecto ecto_sql ex_doc finch gettext
    guardian jason phoenix phoenix_ecto phoenix_live_dashboard phoenix_swagger plug
    postgrex swoosh telemetry_metrics telemetry_poller rephi_new
  )

  @doc """
  Checks the application name: lowercase letters, digits and underscores,
  starting with a letter, and not the name of a dependency.
  """
  @spec validate_app(String.t()) :: :ok | {:error, String.t()}
  def validate_app(app) do
    cond do
      not (app =~ @app_pattern) ->
        {:error,
         "Application name must start with a letter and have only lowercase letters, " <>
           "numbers and underscores, got: #{inspect(app)}. Use --app to set it."}

      app in @reserved_apps ->
        {:error,
         "Application name cannot be #{inspect(app)}: it is the name of a dependency. " <>
           "Use --app to set another one."}

      true ->
        :ok
    end
  end

  @doc """
  Checks the module name: an alias such as `AcmeHub` or `Acme.Hub`, that does
  not name a module that already exists (`Phoenix`, `Mix`...).
  """
  @spec validate_module(String.t()) :: :ok | {:error, String.t()}
  def validate_module(module) do
    cond do
      not (module =~ @module_pattern) ->
        {:error,
         "Module name must be a valid Elixir alias (for example: AcmeHub), got: " <>
           "#{inspect(module)}. Use --module to set it."}

      Code.ensure_loaded?(Module.concat([module])) or
          Code.ensure_loaded?(Module.concat([module <> "Web"])) ->
        {:error,
         "Module name #{module} is already taken by a module of Elixir or of a loaded " <>
           "application. Use --module to set another one."}

      true ->
        :ok
    end
  end
end
