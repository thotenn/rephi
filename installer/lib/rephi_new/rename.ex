defmodule RephiNew.Rename do
  @moduledoc """
  Renames the template (`rephi` / `Rephi`) to the new project's names, as whole
  names in one pass. URLs, the `rephi.*` Mix tasks and npm names are kept on purpose.
  """

  @url ~r{https?://[^\s"'`<>)\]]+}

  @doc "Replaces the template's names in `text`."
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

  # One alternation, so a replacement is never matched again. Skips `Mix.Tasks.Rephi.*`,
  # `rephi.gen`/`rephi.new`, npm names (`@rephi/`, `rephi-*`), `"rephi":` and `~/lib/rephi`.
  defp name_regex do
    ~r/(?<![A-Za-z0-9_.])Rephi(?![a-z0-9])(?!\.(?:Gen|New)\b)|(?<![A-Za-z0-9@.-])(?<!~\/lib\/)rephi(?![A-Za-z0-9-])(?!\.(?:gen|new)\b)(?!":)(?!\.copyToPhoenix)|(?<![A-Za-z0-9])REPHI(?![A-Z0-9])/
  end

  @doc """
  Renames every segment of a relative `path`; Mix task files keep their names.
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

  @reserved_apps ~w(
    elixir eex ex_unit iex logger mix kernel stdlib crypto ssl public_key
    runtime_tools inets compiler
    bandit bcrypt_elixir cors_plug dns_cluster ecto ecto_sql ex_doc finch gettext
    guardian jason open_api_spex phoenix phoenix_ecto phoenix_live_dashboard plug
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
