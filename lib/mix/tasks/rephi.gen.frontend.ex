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

    * `--template` - the app to copy (default: `example`). Two kinds of apps
      are understood, by the config file they have:

        * a Vite single-page app (`vite.config.ts`), like `apps/example`. It
          is built into `priv/static/apps/NAME` by `yarn build` and served by
          Phoenix at `/app/NAME/`. Its base path and dev server port live in
          `packages/shared-components/src/env.ts`, where the new app gets its
          own entry.

        * an Astro site (`astro.config.ts`), like `apps/example-astro`. It is
          a static site meant for any static host, so it keeps
          `"rephi": { "copyToPhoenix": false }` and `yarn build` does not copy
          it into Phoenix (see the printed instructions to serve it from
          Phoenix anyway).

    * `--port` - the port of the app's dev server. By default the first port
      not used by another app, starting at 5001 for Vite apps and at 4322 for
      Astro sites.

  ## What it changes

    * `apps/NAME/` - the copy of the template, with its package name
      (`rephi-NAME`), base path and dev server port. Build output,
      `node_modules` and local `.env` files are not copied.
    * `package.json` - the `NAME:dev` and `NAME:build` scripts.
    * `packages/shared-components/src/env.ts` (Vite apps) - the app's entry in
      `APPS`, and its `VITE_<NAME>_PORT` variable in `vite-env.d.ts`.
    * `config/dev.exs` - the dev server's origin in the development CORS list,
      so the app can call the API while it runs on its own port.

  Phoenix needs no change: `RephiWeb.Plugs.FrontendAppPlug` serves any
  directory of `priv/static/apps/`.

  NAME uses lowercase letters, digits, `_` and `-`, starts with a letter or a
  digit and has at most 64 characters (the names `FrontendAppPlug` serves).
  Everything is checked before anything is written: when the task fails, it
  has changed nothing.
  """

  use Mix.Task

  @apps_dir "apps"
  @root_package "package.json"
  @shared_env "packages/shared-components/src/env.ts"
  @shared_env_types "packages/shared-components/src/vite-env.d.ts"
  @dev_config "config/dev.exs"

  # Same pattern as RephiWeb.Plugs.FrontendAppPlug.
  @name_pattern ~r/\A[a-z0-9][a-z0-9_-]{0,63}\z/

  # Names that would clash with something that is not an app.
  @reserved ~w(shared packages node_modules)

  # Left out of the copy: build output, dependencies, caches and local env files.
  @skip_copy ~w(node_modules dist .astro .vite .wrangler .cache .turbo .env .env.local .dev.vars)

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
         {:ok, kind} <- template_kind(template_dir),
         :ok <- check_free(target_dir),
         {:ok, root} <- read_json(@root_package),
         {:ok, template_pkg} <- read_json(Path.join(template_dir, "package.json")),
         {:ok, prefix} <- package_prefix(template_pkg, template),
         package = prefix <> name,
         :ok <- check_package_name_free(package),
         {:ok, root} <- add_scripts(root, name, package),
         {:ok, port} <- pick_port(kind, port),
         {:ok, app_files} <- app_files(kind, template_dir, template, name, package, port),
         {:ok, shared_files} <- shared_files(kind, template, name, port) do
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
         files: [{@root_package, encode_json(root)} | shared_files] ++ cors_files,
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
        templates =
          @apps_dir
          |> File.ls()
          |> case do
            {:ok, entries} -> entries |> Enum.filter(&File.dir?(Path.join(@apps_dir, &1)))
            _ -> []
          end
          |> Enum.sort()

        {:error,
         "Template app #{dir} not found. Run the task from the root of the project. " <>
           "Available templates: #{Enum.join(templates, ", ")}"}

      File.regular?(Path.join(dir, "vite.config.ts")) ->
        {:ok, :vite}

      astro_config(dir) ->
        {:ok, :astro}

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

  ## Root package.json

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
      {:ok, entries} -> Enum.filter(entries, &File.dir?(Path.join(@apps_dir, &1)))
      _ -> []
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

  # Every port mentioned by the apps' configs, the shared env and the dev CORS
  # list, plus Phoenix's own (dev and test).
  defp used_ports do
    sources =
      [@shared_env, @dev_config] ++
        Path.wildcard("apps/*/{vite,astro}.config.{ts,mts,mjs,js}")

    from_files =
      sources
      |> Enum.flat_map(fn path ->
        case File.read(path) do
          {:ok, contents} ->
            Regex.scan(
              ~r/(?:port:\s*|_PORT\s*\|\|\s*['"]?|localhost:|\|\|\s*)(\d{4,5})\b/,
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

  ## The app's own files

  defp app_files(:vite, template_dir, template, name, package, _port) do
    pkg_path = Path.join(template_dir, "package.json")

    with {:ok, pkg} <- read_json(pkg_path),
         {:ok, vite} <- read(Path.join(template_dir, "vite.config.ts")),
         :ok <- require_anchor(vite, apps_ref(template), "#{template_dir}/vite.config.ts") do
      router_path = Path.join([template_dir, "src", "router.tsx"])

      router =
        case File.read(router_path) do
          {:ok, router} -> [{"src/router.tsx", replace_apps_ref(router, template, name)}]
          _ -> []
        end

      {:ok,
       [
         {"package.json", encode_json(put_ordered(pkg, "name", package))},
         {"vite.config.ts", replace_apps_ref(vite, template, name)}
         | router
       ]}
    end
  end

  defp app_files(:astro, template_dir, template, name, package, port) do
    pkg_path = Path.join(template_dir, "package.json")
    config_file = astro_config(template_dir)

    with {:ok, pkg} <- read_json(pkg_path),
         {:ok, config} <- read(Path.join(template_dir, config_file)),
         :ok <-
           require_anchor(config, ~r/port:\s*\d+/, "the dev server port in #{config_file}") do
      config = Regex.replace(~r/port:\s*\d+/, config, "port: #{port}", global: false)
      template_package = pkg["name"]

      # Plain-text files that name the template (Wrangler project, docs).
      texts =
        ~w(wrangler.jsonc wrangler.json wrangler.toml .env.example README.md)
        |> Enum.flat_map(fn file ->
          case File.read(Path.join(template_dir, file)) do
            {:ok, text} -> [{file, rename_text(text, template_package, package, template, name)}]
            _ -> []
          end
        end)

      {:ok,
       [
         {"package.json", encode_json(put_ordered(pkg, "name", package))},
         {config_file, config} | texts
       ]}
    end
  end

  defp rename_text(text, template_package, package, template, name) do
    text
    |> String.replace(template_package, package)
    |> then(&Regex.replace(~r/(?<![a-z0-9_-])#{Regex.escape(template)}(?![a-z0-9_-])/, &1, name))
  end

  defp require_anchor(contents, %Regex{} = regex, what) do
    if contents =~ regex, do: :ok, else: {:error, "Could not find #{what}."}
  end

  defp require_anchor(contents, anchor, file) when is_binary(anchor) do
    if String.contains?(contents, anchor),
      do: :ok,
      else: {:error, "Could not find #{inspect(anchor)} in #{file}."}
  end

  # `env.APPS.example`, or `env.APPS["my-app"]` for names that are not
  # JavaScript identifiers.
  defp apps_ref(name) do
    if identifier?(name), do: "env.APPS.#{name}", else: ~s(env.APPS["#{name}"])
  end

  defp apps_key(name), do: if(identifier?(name), do: name, else: ~s("#{name}"))

  defp identifier?(name), do: name =~ ~r/\A[a-z_][a-z0-9_]*\z/

  defp replace_apps_ref(contents, template, name) do
    String.replace(contents, apps_ref(template), apps_ref(name))
  end

  defp env_var(name), do: "VITE_#{name |> String.upcase() |> String.replace("-", "_")}_PORT"

  ## Shared files (Vite apps)

  defp shared_files(:astro, _template, _name, _port), do: {:ok, []}

  defp shared_files(:vite, template, name, port) do
    with {:ok, env} <- read(@shared_env),
         {:ok, env} <- add_app_entry(env, template, name, port) do
      types =
        case File.read(@shared_env_types) do
          {:ok, types} -> add_port_type(types, template, name)
          _ -> nil
        end

      {:ok, [{@shared_env, env} | if(types, do: [{@shared_env_types, types}], else: [])]}
    end
  end

  # Copies the template's entry of `APPS` in env.ts, renamed, and appends it as
  # the last entry of the object.
  defp add_app_entry(env, template, name, port) do
    with {:ok, apps_open, apps_close} <- object_after(env, ~r/\bAPPS\s*:\s*\{/),
         body = binary_part(env, apps_open, apps_close - apps_open),
         {:ok, entry_start, entry_end} <- template_entry(body, template) do
      entry = binary_part(body, entry_start, entry_end - entry_start)
      template_var = env_var(template)

      with :ok <- require_anchor(entry, template_var, "the #{template} entry of #{@shared_env}"),
           :ok <-
             require_anchor(
               entry,
               ~r/#{template_var}\s*\|\|\s*['"]?\d+/,
               "the default port of #{template_var} in #{@shared_env}"
             ) do
        new_entry =
          entry
          |> String.replace(~r/\A#{Regex.escape(apps_key(template))}/, apps_key(name))
          |> String.replace("/app/#{template}\"", "/app/#{name}\"")
          |> String.replace("/app/#{template}'", "/app/#{name}'")
          |> String.replace(
            ~r/#{template_var}(\s*\|\|\s*['"]?)\d+/,
            "#{env_var(name)}\\g{1}#{port}"
          )

        # Insert after the last entry: keep what follows it (whitespace before
        # the closing brace), adding a comma unless there is one already.
        trimmed = String.trim_trailing(body)
        separator = if String.ends_with?(trimmed, ","), do: "", else: ","
        indent = indentation(body, entry_start)
        tail = binary_part(body, byte_size(trimmed), byte_size(body) - byte_size(trimmed))

        new_body = trimmed <> separator <> "\n" <> indent <> new_entry <> tail

        {:ok,
         binary_part(env, 0, apps_open) <>
           new_body <> binary_part(env, apps_close, byte_size(env) - apps_close)}
      end
    else
      :error -> {:error, "Could not find the APPS object in #{@shared_env}."}
      {:error, _} = error -> error
    end
  end

  defp template_entry(body, template) do
    key = ~r/(?:^|[\s,{])(#{Regex.escape(apps_key(template))})\s*:\s*\{/

    case Regex.run(key, body, return: :index) do
      [_, {start, _}] ->
        case object_after(body, key) do
          {:ok, _open, close} -> {:ok, start, close + 1}
          :error -> {:error, "The #{template} entry of #{@shared_env} is not closed."}
        end

      nil ->
        {:error,
         "Could not find the #{template} entry in the APPS object of #{@shared_env}. " <>
           "Vite apps keep their base path and dev port there."}
    end
  end

  defp indentation(body, offset) do
    line_start =
      case :binary.matches(binary_part(body, 0, offset), "\n") do
        [] -> 0
        matches -> matches |> List.last() |> then(fn {pos, _} -> pos + 1 end)
      end

    body |> binary_part(line_start, offset - line_start) |> String.replace(~r/\S.*/, "")
  end

  # Finds the `{` that ends the first match of `regex` and its matching `}`.
  # Returns the offsets just after the `{` and of the `}`. Strings and
  # comments are skipped while counting braces.
  defp object_after(text, regex) do
    case Regex.run(regex, text, return: :index) do
      [{start, length} | _] ->
        open = start + length

        case closing_brace(text, open, 1) do
          nil -> :error
          close -> {:ok, open, close}
        end

      nil ->
        :error
    end
  end

  defp closing_brace(text, pos, depth) when pos < byte_size(text) do
    case :binary.at(text, pos) do
      ?{ ->
        closing_brace(text, pos + 1, depth + 1)

      ?} when depth == 1 ->
        pos

      ?} ->
        closing_brace(text, pos + 1, depth - 1)

      quote when quote in [?", ?', ?`] ->
        closing_brace(text, skip_string(text, pos + 1, quote), depth)

      ?/ ->
        case :binary.at(text, pos + 1) do
          ?/ -> closing_brace(text, skip_until(text, pos, "\n"), depth)
          ?* -> closing_brace(text, skip_until(text, pos, "*/") + 1, depth)
          _ -> closing_brace(text, pos + 1, depth)
        end

      _ ->
        closing_brace(text, pos + 1, depth)
    end
  end

  defp closing_brace(_text, _pos, _depth), do: nil

  defp skip_string(text, pos, quote) when pos < byte_size(text) do
    case :binary.at(text, pos) do
      ?\\ -> skip_string(text, pos + 2, quote)
      ^quote -> pos + 1
      _ -> skip_string(text, pos + 1, quote)
    end
  end

  defp skip_string(text, _pos, _quote), do: byte_size(text)

  defp skip_until(text, pos, marker) do
    rest = binary_part(text, pos, byte_size(text) - pos)

    case :binary.match(rest, marker) do
      {at, _} -> pos + at + 1
      :nomatch -> byte_size(text)
    end
  end

  # `readonly VITE_EXAMPLE_PORT: number` -> the same line for the new app,
  # after the last `VITE_*_PORT` line.
  defp add_port_type(types, template, name) do
    template_line = ~r/^[ \t]*readonly\s+#{env_var(template)}\s*:[^\n]*$/m
    port_line = ~r/^[ \t]*readonly\s+VITE_\w+_PORT\s*:[^\n]*$/m

    with [line] <- Regex.run(template_line, types),
         [_ | _] = matches <- Regex.scan(port_line, types, return: :index) do
      [{start, length}] = List.last(matches)
      at = start + length
      new_line = String.replace(line, env_var(template), env_var(name))

      binary_part(types, 0, at) <>
        "\n" <> new_line <> binary_part(types, at, byte_size(types) - at)
    else
      _ -> nil
    end
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
  # rename; the shared files are written afterwards, and restored if writing
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

  defp copy_tree(source, target) do
    File.mkdir_p!(target)

    source
    |> File.ls!()
    |> Enum.reject(&(&1 in @skip_copy or String.ends_with?(&1, ".log")))
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

    Next steps, from the root of the project:

        yarn install          # links the new workspace
        yarn shared:build     # the app reads its base path and port from the shared package
        yarn #{plan.name}:dev#{dev_padding(plan.name)}# http://localhost:#{plan.port}/app/#{plan.name}/
        yarn build            # builds every app and copies them to priv/static/apps

    Phoenix then serves it at http://localhost:4000/app/#{plan.name}/
    #{cors_note(plan)}
    """
  end

  defp next_steps(%{kind: :astro} = plan) do
    """

    Astro site #{plan.name} created in #{plan.target_dir} (#{plan.package}).

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
