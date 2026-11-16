defmodule Mix.Tasks.Rephi.NewTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  @template Path.expand("../../../..", __DIR__)

  setup %{tmp_dir: tmp_dir} do
    Mix.shell(Mix.Shell.Process)

    git_identity = ~w(GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL)
    previous = Map.new(git_identity, &{&1, System.get_env(&1)})

    for var <- git_identity,
        do: System.put_env(var, if(var =~ "EMAIL", do: "t@example.com", else: "Test"))

    on_exit(fn ->
      Mix.shell(Mix.Shell.IO)

      for {var, value} <- previous do
        if value, do: System.put_env(var, value), else: System.delete_env(var)
      end
    end)

    {:ok,
     template: fixture_template(Path.join(tmp_dir, "template")), out: Path.join(tmp_dir, "out")}
  end

  defp fixture_template(dir) do
    files = %{
      "mix.exs" => """
      defmodule Rephi.MixProject do
        use Mix.Project
        def project, do: [app: :rephi, version: "0.1.0"]
        def application, do: [mod: {Rephi.Application, []}]
      end
      """,
      "lib/rephi.ex" => "defmodule Rephi do\nend\n",
      "lib/rephi_web.ex" => "defmodule RephiWeb do\nend\n",
      "lib/rephi_web/endpoint.ex" => """
      defmodule RephiWeb.Endpoint do
        @session_options [key: "_rephi_key", signing_salt: "TEMPLATE"]
      end
      """,
      "lib/mix/tasks/rephi.gen.frontend.ex" =>
        "defmodule Mix.Tasks.Rephi.Gen.Frontend do\n  # rephi-example, RephiWeb\nend\n",
      "config/config.exs" =>
        "import Config\nconfig :rephi, RephiWeb.Endpoint, live_view: [signing_salt: \"TEMPLATE\"]\n",
      "config/dev.exs" => """
      import Config
      config :rephi, Rephi.Repo, database: System.get_env("DB_NAME", "rephi_dev")
      config :rephi, RephiWeb.Endpoint,
        secret_key_base: System.get_env("SECRET_KEY_BASE", "TEMPLATE-SKB-DEV")
      config :rephi, RephiWeb.Auth.Guardian, secret_key: "TEMPLATE-GUARDIAN-DEV"
      """,
      "config/test.exs" => """
      import Config
      config :rephi, RephiWeb.Endpoint, secret_key_base: "TEMPLATE-SKB-TEST"
      config :rephi, RephiWeb.Auth.Guardian, secret_key: "TEMPLATE-GUARDIAN-TEST"
      """,
      "priv/repo/seeds.exs" => "Rephi.Seeds.run()\n",
      "priv/static/favicon.ico" => <<0, 1, 2, "rephi">>,
      ".env.example" => "# DB_NAME=rephi_dev\n",
      "setup.sh" => "#!/usr/bin/env bash\necho rephi\n",
      "package.json" => ~s({"name": "rephi-monorepo"}\n),
      "apps/example/package.json" => ~s({"name": "rephi-example"}\n),
      "installer/mix.exs" => "",
      "LICENSE" => "MIT",
      "CHANGELOG.md" => "# Changelog",
      "README.md" => "# Rephi"
    }

    for {path, contents} <- files do
      File.mkdir_p!(Path.join(dir, Path.dirname(path)))
      File.write!(Path.join(dir, path), contents)
    end

    File.chmod!(Path.join(dir, "setup.sh"), 0o755)

    for args <- [~w(init --quiet), ~w(add --all), ~w(commit --quiet -m template)] do
      {_, 0} = System.cmd("git", args, cd: dir, stderr_to_stdout: true)
    end

    dir
  end

  defp new(args), do: Mix.Tasks.Rephi.New.run(args)

  defp new_error(args) do
    assert catch_exit(new(args)) == {:shutdown, 1}
    assert_received {:mix_shell, :error, [message]}
    message
  end

  defp read(dir, path), do: File.read!(Path.join(dir, path))

  defp leftovers(out) do
    case File.ls(out) do
      {:ok, entries} -> Enum.filter(entries, &String.starts_with?(&1, "."))
      {:error, :enoent} -> []
    end
  end

  test "creates a renamed project with its own secrets and an initial commit",
       %{template: template, out: out} do
    project = Path.join(out, "acme_hub")
    new([project, "--from", template, "--no-install"])

    assert read(project, "mix.exs") =~ "defmodule AcmeHub.MixProject"
    assert read(project, "mix.exs") =~ "app: :acme_hub"
    assert read(project, "mix.exs") =~ "mod: {AcmeHub.Application, []}"
    assert read(project, "lib/acme_hub.ex") =~ "defmodule AcmeHub do"
    assert read(project, "lib/acme_hub_web.ex") =~ "defmodule AcmeHubWeb do"
    assert read(project, "lib/acme_hub_web/endpoint.ex") =~ ~s(key: "_acme_hub_key")
    assert read(project, "config/dev.exs") =~ ~s("acme_hub_dev")
    assert read(project, "priv/repo/seeds.exs") == "AcmeHub.Seeds.run()\n"
    assert read(project, ".env.example") == "# DB_NAME=acme_hub_dev\n"

    assert read(project, "lib/mix/tasks/rephi.gen.frontend.ex") ==
             "defmodule Mix.Tasks.Rephi.Gen.Frontend do\n  # rephi-example, AcmeHubWeb\nend\n"

    assert read(project, "package.json") == ~s({"name": "rephi-monorepo"}\n)
    assert read(project, "apps/example/package.json") == ~s({"name": "rephi-example"}\n)
    assert read(project, "priv/static/favicon.ico") == <<0, 1, 2, "rephi">>

    refute File.exists?(Path.join(project, "lib/rephi_web"))
    refute File.exists?(Path.join(project, "installer"))
    refute File.exists?(Path.join(project, "LICENSE"))
    refute File.exists?(Path.join(project, "CHANGELOG.md"))
    assert read(project, "README.md") =~ "# AcmeHub"
    assert read(project, "README.md") =~ "./setup.sh"

    all_config =
      Enum.map_join(
        ~w(config/config.exs config/dev.exs config/test.exs lib/acme_hub_web/endpoint.ex),
        &read(project, &1)
      )

    refute all_config =~ "TEMPLATE"

    assert File.stat!(Path.join(project, "setup.sh")).mode |> Bitwise.band(0o111) != 0

    assert {log, 0} = System.cmd("git", ~w(log --format=%s), cd: project)
    assert log == "Initial commit (mix rephi.new)\n"
    assert {"", 0} = System.cmd("git", ~w(status --porcelain), cd: project)
    assert {"main\n", 0} = System.cmd("git", ~w(branch --show-current), cd: project)

    assert leftovers(out) == []
  end

  test "--app and --module", %{template: template, out: out} do
    project = Path.join(out, "somewhere")

    new([
      project,
      "--from",
      template,
      "--no-install",
      "--no-git",
      "--app",
      "hub",
      "--module",
      "Acme.Hub"
    ])

    assert read(project, "mix.exs") =~ "defmodule Acme.Hub.MixProject"
    assert read(project, "lib/hub_web.ex") =~ "defmodule Acme.HubWeb do"
    refute File.exists?(Path.join(project, ".git"))
  end

  test "refuses invalid names before creating anything", %{template: template, out: out} do
    assert new_error([Path.join(out, "My-App"), "--from", template]) =~ "Application name"
    assert new_error([Path.join(out, "1app"), "--from", template]) =~ "Application name"
    assert new_error([Path.join(out, "phoenix"), "--from", template]) =~ "name of a dependency"

    assert new_error([Path.join(out, "x"), "--module", "acme", "--from", template]) =~
             "valid Elixir alias"

    assert new_error([Path.join(out, "x"), "--module", "Enum", "--from", template]) =~
             "already taken"

    refute File.exists?(out)
  end

  test "refuses an existing path", %{template: template, out: out} do
    File.mkdir_p!(Path.join(out, "taken"))
    File.write!(Path.join([out, "taken", "keep.txt"]), "mine")

    assert new_error([Path.join(out, "taken"), "--from", template]) =~ "already exists"
    assert File.ls!(Path.join(out, "taken")) == ["keep.txt"]
  end

  test "a template that cannot be fetched leaves nothing behind", %{out: out} do
    message = new_error([Path.join(out, "acme"), "--from", Path.join(out, "missing.git")])
    assert message =~ "Could not fetch the template"
    refute File.exists?(Path.join(out, "acme"))
    assert leftovers(out) == []
  end

  test "a template whose secrets changed shape is refused", %{template: template, out: out} do
    File.write!(Path.join(template, "config/test.exs"), "import Config\n")
    {_, 0} = System.cmd("git", ~w(commit --quiet -am drop), cd: template)

    assert new_error([Path.join(out, "acme"), "--from", template]) =~ "expected 2, found 1"
    refute File.exists?(Path.join(out, "acme"))
    assert leftovers(out) == []
  end

  test "bad arguments", %{out: out} do
    assert new_error([Path.join(out, "a"), "--bogus"]) =~ "--bogus"
    assert new_error([Path.join(out, "a"), Path.join(out, "b")]) =~ "single PATH"
  end

  @tag :template
  test "the Rephi template", %{out: out} do
    if File.dir?(Path.join(@template, ".git")) do
      project = Path.join(out, "acme_hub")
      new([project, "--from", @template, "--no-install"])

      {files, 0} = System.cmd("git", ["ls-files"], cd: project)

      leftovers =
        for file <- String.split(files, "\n", trim: true),
            not String.starts_with?(file, ["apps/", "packages/"]),
            Path.extname(file) not in ~w(.js .json .lock),
            Path.basename(file) not in ~w(package.json yarn.lock .yarnrc.yml),
            contents = File.read!(Path.join(project, file)),
            String.valid?(contents),
            line <- String.split(contents, "\n"),
            line =~ ~r/rephi/i,
            stripped =
              line
              |> String.replace(~r{\[Rephi\]\(https?://\S+}, "")
              |> String.replace(~r{https?://\S+}, "")
              |> String.replace(~r/Mix\.Tasks\.Rephi\.\w+|rephi\.(gen|new)[\w.]*/, "")
              |> String.replace(
                ~r/@rephi\/|rephi-[\w*]+|rephi-|"rephi"|rephi\.copyToPhoenix|~\/lib\/rephi/,
                ""
              ),
            # Names glued to other words (`configureRephi`) are not the template's.
            stripped =~ ~r/(?<![A-Za-z0-9])(rephi|Rephi|REPHI)(?![a-z0-9])/,
            do: {file, line}

      assert leftovers == []

      for file <-
            Path.wildcard(Path.join(project, "{lib,config,test}/**/*.{ex,exs}")) ++
              Path.wildcard(Path.join(project, "priv/repo/**/*.exs")) do
        assert {:ok, _} = Code.string_to_quoted(File.read!(file)), file
      end

      template_config = File.read!(Path.join(@template, "config/dev.exs"))
      project_config = File.read!(Path.join(project, "config/dev.exs"))
      [_, template_key] = Regex.run(~r/secret_key: "([^"]+)"/, template_config)
      refute project_config =~ template_key
    end
  end
end
