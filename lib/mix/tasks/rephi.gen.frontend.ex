defmodule Mix.Tasks.Rephi.Gen.Frontend do
  @shortdoc "Generates a new frontend app from one of the apps in apps/"

  @moduledoc """
  Generates a new frontend app by copying a template app from `apps/`.

      mix rephi.gen.frontend NAME [--template TEMPLATE] [--port PORT]

  ## Examples

      mix rephi.gen.frontend dashboard
      mix rephi.gen.frontend admin-panel --port 5020
      mix rephi.gen.frontend site --template example-astro

  ## Options

    * `--template` - the app to copy (default: `example`). Every app keeps
      the settings that depend on where it runs in its own `app.config.ts`:

          export const appConfig = {
            basename: "/app/example",
            port: 5001,
          } as const;

      Two kinds of apps are understood, by the config file that reads it:

        * a Vite single-page app (`vite.config.ts`), like `apps/example`. It
          is built into `priv/static/apps/NAME` by `yarn build` and served by
          Phoenix at `/app/NAME/`, so its `basename` becomes `/app/NAME`.

        * an Astro site (`astro.config.ts`), like `apps/example-astro`. It is
          a static site meant for any static host: it keeps its `basename`
          (`/`) and `"rephi": { "copyToPhoenix": false }`, so `yarn build`
          does not copy it into Phoenix (see the printed instructions to
          serve it from Phoenix anyway).

    * `--port` - the port of the app's dev server. By default the first port
      not used by another app, starting at 5001 for Vite apps and at 4322 for
      Astro sites.

  ## What it changes

    * `apps/NAME/` - the copy of the template, with its package name
      (`rephi-NAME`) and its `app.config.ts` (`basename`, `port`). Build
      output, `node_modules`, caches and local `.env` files are not copied.
      Mentions of the template's package, scripts, path and dev port in the
      copied sources and docs are renamed too.
    * `package.json` - the `NAME:dev` and `NAME:build` scripts.
    * `config/dev.exs` - the dev server's origin in the development CORS list,
      so the app can call the API while it runs on its own port.

  Nothing in `packages/` changes, and Phoenix needs no change either:
  `RephiWeb.Plugs.FrontendAppPlug` serves any directory of
  `priv/static/apps/`.

  NAME uses lowercase letters, digits, `_` and `-`, starts with a letter or a
  digit and has at most 64 characters (the names `FrontendAppPlug` serves).
  Everything is checked before anything is written: when the task fails, it
  has changed nothing.
  """

  use Mix.Task

  @apps_dir "apps"
  @root_package "package.json"
  @app_config "app.config.ts"
  @dev_config "config/dev.exs"

  # Same pattern as RephiWeb.Plugs.FrontendAppPlug.
  @name_pattern ~r/\A[a-z0-9][a-z0-9_-]{0,63}\z/

  # Names that would clash with something that is not an app.
  @reserved ~w(shared packages node_modules)

  # Left out of the copy: build output, dependencies, caches and local env files.
  @skip_copy ~w(node_modules dist .astro .vite .wrangler .cache .turbo .env .env.local .dev.vars)

  # The two values of app.config.ts the task rewrites. Each must appear once.
  @basename_line ~r/\bbasename:\s*(["'])[^"'\n]*\1/
  @port_line ~r/\bport:\s*\d+/

  # Copied files whose text is checked for mentions of the template.
  @text_extensions ~w(.ts .tsx .mts .js .jsx .mjs .cjs .astro .md .html .json .jsonc .toml)
  @text_files ~w(.env.example)

  @switches [template: :string, port: :integer]

  @impl Mix.Task
  def run(argv) do
    case OptionParser.parse(argv, strict: @switches) do
      {opts, [name], []} ->
        generate(name, Keyword.put_new(opts, :template, "example"))

      {_opts, _args, [{switch, _} | _]} ->
        fail("Unknown or invalid option #{switch}.\n\n" <> usage())

      _ ->
        fail(usage())
    end
  end

  defp usage do
    "Usage: mix rephi.gen.frontend NAME [--template TEMPLATE] [--port PORT]"
  end

  defp generate(name, opts) do
    with :ok <- validate_name(name),
         {:ok, plan} <- plan(name, opts[:template], opts[:port]) do
      apply_plan(plan)
      Mix.shell().info(next_steps(plan))
    else
      {:error, message} -> fail(message)
    end
  end

  defp fail(message) do
    Mix.shell().error(message)
    exit({:shutdown, 1})
  end

  ## Validation

  defp validate_name(name) do
    cond do
      name =~ @name_pattern and name not in @reserved ->
        :ok

      name in @reserved ->
        {:error, "The name #{inspect(name)} is reserved. Choose another one."}

      String.downcase(name) =~ @name_pattern ->
        {:error,
         "Invalid app name #{inspect(name)}: use lowercase letters (#{inspect(String.downcase(name))})."}

      true ->
        {:error,
         "Invalid app name #{inspect(name)}. Use lowercase letters, digits, \"_\" and \"-\", " <>
           "starting with a letter or a digit (at most 64 characters)."}
    end
  end

  ## Planning: read and check everything, compute every change in memory

  defp plan(name, template, port) do
    template_dir = Path.join(@apps_dir, template)
    target_dir = Path.join(@apps_dir, name)

    with :ok <- check_template_name(template),
         {:ok, kind, config_file} <- template_kind(template_dir),
         :ok <- check_free(target_dir),
         {:ok, app_config} <- read_app_config(template_dir, config_file),
         {:ok, root} <- read_json(@root_package),
         {:ok, template_pkg} <- read_json(Path.join(template_dir, "package.json")),
         {:ok, prefix} <- package_prefix(template_pkg, template),
         package = prefix <> name,
         :ok <- check_package_name_free(package),
         {:ok, root} <- add_scripts(root, name, package),
         {:ok, port} <- pick_port(kind, port) do
      source = %{
        name: template,
        dir: template_dir,
        package: template_pkg["name"],
        port: config_port(app_config)
      }

      app_files =
        [
          {"package.json", encode_json(put_ordered(template_pkg, "name", package))},
          {@app_config, set_app_config(app_config, kind, name, port)}
        ] ++ renamed_texts(kind, source, name, package, port)

      {cors, cors_files} =
        case dev_cors(port) do
          {:ok, config} -> {:added, [{@dev_config, config}]}
          :present -> {:present, []}
          :error -> {:missing, []}
        end

      {:ok,
       %{
         name: name,
         kind: kind,
         port: port,
         package: package,
         template_dir: template_dir,
         target_dir: target_dir,
         app_files: app_files,
         files: [{@root_package, encode_json(root)} | cors_files],
         cors: cors
       }}
    end
  end

  defp check_template_name(template) do
    if template =~ @name_pattern do
      :ok
    else
      {:error, "Invalid template name #{inspect(template)}."}
    end
  end

  defp template_kind(dir) do
    cond do
      not File.dir?(dir) ->
        {:error,
         "Template app #{dir} not found. Run the task from the root of the project. " <>
           "Available templates: #{Enum.join(Enum.sort(existing_apps()), ", ")}"}

      File.regular?(Path.join(dir, "vite.config.ts")) ->
        {:ok, :vite, "vite.config.ts"}

      config = astro_config(dir) ->
        {:ok, :astro, config}

      true ->
        {:error,
         "#{dir} is neither a Vite app (vite.config.ts) nor an Astro site (astro.config.ts), " <>
           "so it cannot be used as a template."}
    end
  end

  defp astro_config(dir) do
    Enum.find(
      ~w(astro.config.ts astro.config.mts astro.config.mjs astro.config.js),
      &File.regular?(Path.join(dir, &1))
    )
  end

  defp check_free(target_dir) do
    if File.exists?(target_dir) do
      {:error, "#{target_dir} already exists. Choose another name or remove it first."}
    else
      :ok
    end
  end

  ## app.config.ts

  # The template's app.config.ts, checked: the Vite/Astro config imports it,
  # and it has exactly one `basename: "..."` and one `port: N`.
  defp read_app_config(template_dir, config_file) do
    path = Path.join(template_dir, @app_config)

    with {:ok, config} <- read(Path.join(template_dir, config_file)),
         :ok <- check_imports_app_config(config, Path.join(template_dir, config_file)),
         {:ok, app_config} <- read_existing(path, template_dir),
         :ok <- check_once(app_config, @basename_line, ~s(basename: "<path>"), path),
         :ok <- check_once(app_config, @port_line, "port: <number>", path) do
      {:ok, app_config}
    end
  end

  defp check_imports_app_config(config, path) do
    if config =~ ~r/from\s+["']\.\/app\.config(?:\.[mc]?[jt]s)?["']/ do
      :ok
    else
      {:error,
       "#{path} does not import ./app.config, so the new app's base path and dev server " <>
         "port could not be set."}
    end
  end

  defp read_existing(path, template_dir) do
    if File.regular?(path) do
      read(path)
    else
      {:error,
       "#{template_dir} has no #{@app_config} (`export const appConfig = { basename, port }`), " <>
         "so it cannot be used as a template."}
    end
  end

  defp check_once(contents, regex, what, path) do
    case length(Regex.scan(regex, contents)) do
      1 ->
        :ok

      0 ->
        {:error, "Could not find `#{what}` in #{path}."}

      count ->
        {:error,
         "`#{what}` appears #{count} times in #{path}: it must appear once, so the task " <>
           "knows which one to change."}
    end
  end

  defp config_port(app_config) do
    [port] = Regex.run(~r/\bport:\s*(\d+)/, app_config, capture: :all_but_first)
    String.to_integer(port)
  end

  # A Vite app is served by Phoenix at /app/NAME; an Astro site keeps the
  # template's basename ("/", for a static host).
  defp set_app_config(app_config, kind, name, port) do
    app_config =
      if kind == :vite do
        Regex.replace(@basename_line, app_config, ~s(basename: "/app/#{name}"))
      else
        app_config
      end

    Regex.replace(@port_line, app_config, "port: #{port}")
  end

  ## The rest of the copy: mentions of the template in texts and docs

  # Renames, in every text file of the template, its package name, its root
  # scripts (`yarn example:dev`), its path under Phoenix (`/app/example`) and
  # its dev server origin. An Astro site's Wrangler project, `.env.example`
  # and README also name the template itself (`example-astro`).
  defp renamed_texts(kind, template, name, package, port) do
    template.dir
    |> text_files()
    |> Enum.reject(&(&1 in ["package.json", @app_config]))
    |> Enum.flat_map(fn file ->
      original = File.read!(Path.join(template.dir, file))

      renamed =
        original
        |> replace_token(template.package, package)
        |> String.replace("yarn #{template.name}:", "yarn #{name}:")
        |> replace_token("/app/#{template.name}", "/app/#{name}")
        |> replace_token("localhost:#{template.port}", "localhost:#{port}")
        |> rename_in_file(file, kind, template.name, name, port)

      if renamed == original, do: [], else: [{file, renamed}]
    end)
  end

  # Text files of the template, relative to it, as `copy_tree/2` copies them.
  defp text_files(dir, prefix \\ "") do
    dir
    |> File.ls!()
    |> Enum.reject(&skip_copy?/1)
    |> Enum.flat_map(fn entry ->
      path = Path.join(dir, entry)
      relative = if prefix == "", do: entry, else: Path.join(prefix, entry)

      case File.lstat!(path).type do
        :directory ->
          text_files(path, relative)

        :regular ->
          if Path.extname(entry) in @text_extensions or entry in @text_files,
            do: [relative],
            else: []

        _ ->
          []
      end
    end)
  end

  # `VITE_PORT=5001` in a Vite app's .env.example; the template's own name in
  # the files of an Astro site that name its Cloudflare project or document it.
  defp rename_in_file(text, ".env.example", :vite, _template, _name, port),
    do: Regex.replace(~r/\b(VITE_PORT=)\d+/, text, "\\g{1}#{port}")

  defp rename_in_file(text, file, :astro, template, name, _port)
       when file in ~w(wrangler.jsonc wrangler.json wrangler.toml .env.example README.md),
       do: Regex.replace(~r/(?<![a-z0-9_.-])#{Regex.escape(template)}(?![a-z0-9_-])/, text, name)

  defp rename_in_file(text, _file, _kind, _template, _name, _port), do: text

  # `token` when it is not part of a longer name: `/app/example` but not
  # `/app/example-astro`, `rephi-example` but not `rephi-example-astro`.
  defp replace_token(text, token, replacement) do
    Regex.replace(
      ~r/(?<![a-z0-9_-])#{Regex.escape(token)}(?![a-z0-9_-])/,
      text,
      fn _ -> replacement end
    )
  end

  ## package.json files

  defp read_json(path) do
    with {:ok, contents} <- read(path),
         {:ok, json} <- Jason.decode(contents, objects: :ordered_objects) do
      {:ok, json}
    else
      {:error, %Jason.DecodeError{} = error} ->
        {:error, "#{path} is not valid JSON: #{Exception.message(error)}"}

      error ->
        error
    end
  end

  defp read(path) do
    case File.read(path) do
      {:ok, contents} -> {:ok, contents}
      {:error, reason} -> {:error, "Cannot read #{path}: #{:file.format_error(reason)}"}
    end
  end

  # `rephi-example` (template `example`) -> `rephi-`.
  defp package_prefix(template_pkg, template) do
    with name when is_binary(name) <- template_pkg["name"],
         true <- String.ends_with?(name, template) do
      {:ok, String.replace_suffix(name, template, "")}
    else
      _ ->
        {:error,
         "The package name of #{Path.join([@apps_dir, template, "package.json"])} does not end " <>
           "with #{inspect(template)}, so the name of the new package cannot be derived from it."}
    end
  end

  defp check_package_name_free(package) do
    taken =
      Enum.find(Path.wildcard("{apps,packages}/*/package.json"), fn path ->
        case File.read(path) do
          {:ok, contents} -> match?({:ok, %{"name" => ^package}}, Jason.decode(contents))
          _ -> false
        end
      end)

    if taken do
      {:error, "The package name #{package} is already used by #{taken}."}
    else
      :ok
    end
  end

  defp add_scripts(%Jason.OrderedObject{} = root, name, package) do
    case root["scripts"] do
      %Jason.OrderedObject{values: scripts} ->
        new = [
          {"#{name}:dev", "yarn workspace #{package} dev"},
          {"#{name}:build", "yarn workspace #{package} build"}
        ]

        case Enum.filter(new, fn {key, _} -> List.keymember?(scripts, key, 0) end) do
          [] ->
            scripts = insert_scripts(scripts, new)
            {:ok, put_ordered(root, "scripts", %Jason.OrderedObject{values: scripts})}

          taken ->
            {:error,
             "The script(s) #{taken |> Enum.map(&elem(&1, 0)) |> Enum.join(", ")} already exist " <>
               "in #{@root_package}. Choose another name."}
        end

      _ ->
        {:error, "#{@root_package} has no \"scripts\" object."}
    end
  end

  defp add_scripts(_root, _name, _package),
    do: {:error, "#{@root_package} is not a JSON object."}

  # After the last `<app>:dev` / `<app>:build` script, so the app scripts stay
  # together; at the end when there is none.
  defp insert_scripts(scripts, new) do
    apps = existing_apps()

    last =
      scripts
      |> Enum.with_index()
      |> Enum.filter(fn {{key, _}, _} ->
        case String.split(key, ":", parts: 2) do
          [app, task] when task in ["dev", "build"] -> app in apps
          _ -> false
        end
      end)
      |> List.last()

    case last do
      {_, index} -> List.insert_at(scripts, index + 1, new) |> List.flatten()
      nil -> scripts ++ new
    end
  end

  defp existing_apps do
    case File.ls(@apps_dir) do
      {:ok, entries} ->
        Enum.filter(
          entries,
          &(not String.starts_with?(&1, ".") and File.dir?(Path.join(@apps_dir, &1)))
        )

      _ ->
        []
    end
  end

  defp put_ordered(%Jason.OrderedObject{values: values} = object, key, value) do
    %{object | values: List.keyreplace(values, key, 0, {key, value})}
  end

  @doc false
  # Two-space indentation and a final newline, like npm and Yarn write it.
  def encode_json(json), do: Jason.encode!(json, pretty: true) <> "\n"

  ## Ports

  defp pick_port(_kind, port) when is_integer(port) do
    cond do
      port not in 1024..65_535 -> {:error, "--port must be between 1024 and 65535."}
      port in used_ports() -> {:error, "Port #{port} is already used by another app."}
      true -> {:ok, port}
    end
  end

  defp pick_port(kind, nil) do
    used = used_ports()
    first = if kind == :astro, do: 4322, else: 5001
    {:ok, Enum.find(first..65_535, &(&1 not in used))}
  end

  # The ports of every app's app.config.ts, any port written in the apps'
  # Vite/Astro configs or local env files (`VITE_PORT=`), the origins of the
  # dev CORS list, plus Phoenix's own (dev and test).
  defp used_ports do
    sources =
      [@dev_config] ++
        Path.wildcard("apps/*/#{@app_config}") ++
        Path.wildcard("apps/*/{vite,astro}.config.{ts,mts,mjs,js}") ++
        Path.wildcard("apps/*/.env{,.local,.development,.development.local}")

    from_files =
      sources
      |> Enum.flat_map(fn path ->
        case File.read(path) do
          {:ok, contents} ->
            Regex.scan(
              ~r/(?:\bport:\s*|_PORT\s*=\s*['"]?|localhost:|\|\|\s*)(\d{4,5})\b/,
              contents,
              capture: :all_but_first
            )

          _ ->
            []
        end
      end)
      |> Enum.map(fn [port] -> String.to_integer(port) end)

    MapSet.new([4000, 4002 | from_files])
  end

  ## Development CORS

  # Adds "http://localhost:PORT" to the `:cors_origins` list of config/dev.exs.
  defp dev_cors(port) do
    origin = ~s("http://localhost:#{port}")

    with {:ok, config} <- File.read(@dev_config),
         [{start, length}] <-
           Regex.run(~r/:cors_origins,\s*\[(.*?)\]/s, config,
             return: :index,
             capture: :all_but_first
           ) do
      items = binary_part(config, start, length)

      cond do
        String.contains?(items, origin) ->
          :present

        String.contains?(items, "\n") ->
          trimmed = String.trim_trailing(items)
          indent = items |> String.split("\n") |> Enum.at(1, "") |> String.replace(~r/\S.*/, "")
          tail = binary_part(items, byte_size(trimmed), byte_size(items) - byte_size(trimmed))
          new = trimmed <> ",\n" <> indent <> origin <> tail
          {:ok, splice(config, start, length, new)}

        String.trim(items) == "" ->
          {:ok, splice(config, start, length, origin)}

        true ->
          {:ok, splice(config, start, length, String.trim_trailing(items) <> ", " <> origin)}
      end
    else
      _ -> :error
    end
  end

  defp splice(text, start, length, new) do
    binary_part(text, 0, start) <>
      new <> binary_part(text, start + length, byte_size(text) - start - length)
  end

  ## Applying the plan

  # The app is assembled in a temporary directory and moved into place in one
  # rename; the root files are written afterwards, and restored if writing
  # one of them fails.
  defp apply_plan(plan) do
    tmp_dir = Path.join(@apps_dir, ".#{plan.name}.tmp-#{System.unique_integer([:positive])}")

    try do
      copy_tree(plan.template_dir, tmp_dir)

      Enum.each(plan.app_files, fn {file, contents} ->
        File.write!(Path.join(tmp_dir, file), contents)
      end)

      File.rename!(tmp_dir, plan.target_dir)
    rescue
      error ->
        File.rm_rf(tmp_dir)
        reraise error, __STACKTRACE__
    end

    originals = Enum.map(plan.files, fn {path, _} -> {path, File.read!(path)} end)

    try do
      Enum.each(plan.files, fn {path, contents} -> File.write!(path, contents) end)
    rescue
      error ->
        Enum.each(originals, fn {path, contents} -> File.write(path, contents) end)
        File.rm_rf(plan.target_dir)
        reraise error, __STACKTRACE__
    end

    Mix.shell().info([:green, "* creating ", :reset, plan.target_dir])

    Enum.each(plan.files, fn {path, _} ->
      Mix.shell().info([:green, "* updating ", :reset, path])
    end)
  end

  defp skip_copy?(entry), do: entry in @skip_copy or String.ends_with?(entry, ".log")

  defp copy_tree(source, target) do
    File.mkdir_p!(target)

    source
    |> File.ls!()
    |> Enum.reject(&skip_copy?/1)
    |> Enum.each(fn entry ->
      from = Path.join(source, entry)
      to = Path.join(target, entry)

      case File.lstat!(from).type do
        :directory -> copy_tree(from, to)
        :regular -> File.cp!(from, to)
        # Symlinks and special files are not part of a template.
        _ -> :ok
      end
    end)
  end

  ## Output

  defp next_steps(%{kind: :vite} = plan) do
    """

    Frontend app #{plan.name} created in #{plan.target_dir} (#{plan.package}).
    Its base path (/app/#{plan.name}) and dev server port (#{plan.port}) are in
    #{plan.target_dir}/#{@app_config}.

    Next steps, from the root of the project:

        yarn install          # links the new workspace
        yarn shared:build     # the app imports the compiled shared package
        yarn #{plan.name}:dev#{dev_padding(plan.name)}# http://localhost:#{plan.port}/app/#{plan.name}/
        yarn build            # builds every app and copies them to priv/static/apps

    Phoenix then serves it at http://localhost:4000/app/#{plan.name}/
    #{cors_note(plan)}
    """
  end

  defp next_steps(%{kind: :astro} = plan) do
    """

    Astro site #{plan.name} created in #{plan.target_dir} (#{plan.package}).
    Its dev server port (#{plan.port}) is in #{plan.target_dir}/#{@app_config}.

    Next steps, from the root of the project:

        yarn install          # links the new workspace
        yarn shared:build     # the site imports the compiled shared package
        yarn #{plan.name}:dev#{dev_padding(plan.name)}# http://localhost:#{plan.port}/
        yarn #{plan.name}:build#{build_padding(plan.name)}# static site in #{plan.target_dir}/dist

    It is a static site for any static host, so `yarn build` does not copy it
    into Phoenix ("rephi": {"copyToPhoenix": false} in its package.json).
    To serve it from Phoenix at /app/#{plan.name}/ instead:

        ASTRO_BASE=/app/#{plan.name} PUBLIC_API_URL=/api PUBLIC_WS_URL=/socket yarn #{plan.name}:build
        node scripts/copy-builds.js --app #{plan.name}
    #{cors_note(plan)}
    """
  end

  # Aligns the comments with the other lines ("yarn shared:build     # ...").
  defp dev_padding(name), do: String.duplicate(" ", max(1, 13 - String.length(name)))
  defp build_padding(name), do: String.duplicate(" ", max(1, 11 - String.length(name)))

  defp cors_note(%{cors: :added} = plan) do
    """

    The dev server origin http://localhost:#{plan.port} was added to the CORS
    origins of #{@dev_config}: restart `mix phx.server` if it is running.
    """
  end

  defp cors_note(%{cors: :present}), do: ""

  defp cors_note(plan) do
    """

    Add "http://localhost:#{plan.port}" to `config :cors_origins` in #{@dev_config}
    (or to CORS_ORIGINS in .env) so the dev server can call the API.
    """
  end
end
