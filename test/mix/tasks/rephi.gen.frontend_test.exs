defmodule Mix.Tasks.Rephi.Gen.FrontendTest do
  # The task works on the current directory, so the tests cd into a temporary
  # copy of the files it reads. They are the real files of the project: when a
  # template changes shape, these tests are the ones that notice.
  use ExUnit.Case, async: false

  alias Mix.Tasks.Rephi.Gen.Frontend

  @moduletag :tmp_dir

  @files ~w(
    package.json
    config/dev.exs
    packages/shared-components/package.json
    packages/shared-components/src/env.ts
    packages/shared-components/src/vite-env.d.ts
    apps/example/package.json
    apps/example/vite.config.ts
    apps/example/index.html
    apps/example/src/router.tsx
    apps/example-astro/package.json
    apps/example-astro/astro.config.ts
    apps/example-astro/wrangler.jsonc
    apps/example-astro/.env.example
  )

  setup %{tmp_dir: tmp_dir} do
    root = File.cwd!()

    for file <- @files do
      File.mkdir_p!(Path.join(tmp_dir, Path.dirname(file)))
      File.cp!(Path.join(root, file), Path.join(tmp_dir, file))
    end

    # Artifacts that must not be copied into a new app.
    for dir <- ~w(node_modules/some-dep dist) do
      File.mkdir_p!(Path.join([tmp_dir, "apps/example", dir]))
      File.write!(Path.join([tmp_dir, "apps/example", dir, "file.js"]), "")
    end

    File.write!(Path.join(tmp_dir, "apps/example/.env"), "SECRET=1\n")

    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)

    {:ok, tmp_dir: tmp_dir}
  end

  defp gen(tmp_dir, args), do: File.cd!(tmp_dir, fn -> Frontend.run(args) end)

  # Runs the task expecting it to fail; returns the error it printed.
  defp gen_error(tmp_dir, args) do
    assert catch_exit(gen(tmp_dir, args)) == {:shutdown, 1}
    assert_received {:mix_shell, :error, [message]}
    message
  end

  defp read(tmp_dir, file), do: File.read!(Path.join(tmp_dir, file))
  defp json(tmp_dir, file), do: tmp_dir |> read(file) |> Jason.decode!()

  # Every file of the tree, to show that a failed run changed nothing.
  defp snapshot(tmp_dir) do
    for path <- Path.wildcard(Path.join(tmp_dir, "**"), match_dot: true),
        File.regular?(path),
        into: %{},
        do: {Path.relative_to(path, tmp_dir), File.read!(path)}
  end

  describe "a Vite app (the default template)" do
    test "copies the template and registers the app", %{tmp_dir: tmp_dir} do
      gen(tmp_dir, ["demo"])

      assert %{"name" => "rephi-demo"} = json(tmp_dir, "apps/demo/package.json")
      assert read(tmp_dir, "apps/demo/vite.config.ts") =~ "env.APPS.demo.basename"
      refute read(tmp_dir, "apps/demo/vite.config.ts") =~ "env.APPS.example"
      assert read(tmp_dir, "apps/demo/src/router.tsx") =~ "env.APPS.demo.basename"
      assert File.exists?(Path.join(tmp_dir, "apps/demo/index.html"))

      # Build output, dependencies and local env files stay behind.
      refute File.exists?(Path.join(tmp_dir, "apps/demo/node_modules"))
      refute File.exists?(Path.join(tmp_dir, "apps/demo/dist"))
      refute File.exists?(Path.join(tmp_dir, "apps/demo/.env"))

      scripts = json(tmp_dir, "package.json")["scripts"]
      assert scripts["demo:dev"] == "yarn workspace rephi-demo dev"
      assert scripts["demo:build"] == "yarn workspace rephi-demo build"

      env = read(tmp_dir, "packages/shared-components/src/env.ts")
      assert env =~ ~r/demo: \{\s+basename: "\/app\/demo",/
      assert env =~ "import.meta.env.VITE_DEMO_PORT || '5002'"
      # The template's entry is untouched.
      assert env =~ "import.meta.env.VITE_EXAMPLE_PORT || '5001'"

      assert read(tmp_dir, "packages/shared-components/src/vite-env.d.ts") =~
               "readonly VITE_DEMO_PORT: number"

      assert read(tmp_dir, "config/dev.exs") =~ ~s("http://localhost:5002")

      # No leftovers from the temporary copy.
      assert tmp_dir |> Path.join("apps") |> File.ls!() |> Enum.sort() ==
               ["demo", "example", "example-astro"]

      assert_received {:mix_shell, :info, [output]} when is_binary(output)
      output = Enum.join([output | collect_info()], "\n")
      assert output =~ "yarn shared:build"
      assert output =~ "yarn demo:dev"
      assert output =~ "http://localhost:4000/app/demo/"
    end

    test "keeps package.json valid and formatted like Yarn writes it", %{tmp_dir: tmp_dir} do
      original = read(tmp_dir, "package.json")

      # Decoding and encoding the untouched file gives the same bytes: the
      # task only adds the two scripts.
      assert original |> Jason.decode!(objects: :ordered_objects) |> Frontend.encode_json() ==
               original

      gen(tmp_dir, ["demo"])
      gen(tmp_dir, ["demo2"])

      package = read(tmp_dir, "package.json")
      assert {:ok, %{"scripts" => scripts}} = Jason.decode(package)
      assert Map.has_key?(scripts, "demo2:build")

      keys =
        package
        |> Jason.decode!(objects: :ordered_objects)
        |> Map.fetch!(:values)
        |> List.keyfind!("scripts", 0)
        |> elem(1)
        |> Map.fetch!(:values)
        |> Enum.map(&elem(&1, 0))

      # The new scripts go after the other apps' scripts, in order.
      assert Enum.drop_while(keys, &(&1 != "example-astro:build")) ==
               ~w(example-astro:build demo:dev demo:build demo2:dev demo2:build shared:build)

      assert String.ends_with?(package, "}\n")
      refute package =~ ",,"
    end

    test "every app gets its own port", %{tmp_dir: tmp_dir} do
      gen(tmp_dir, ["demo"])
      gen(tmp_dir, ["demo2"])
      gen(tmp_dir, ["demo3", "--port", "5050"])

      env = read(tmp_dir, "packages/shared-components/src/env.ts")
      assert env =~ "VITE_DEMO_PORT || '5002'"
      assert env =~ "VITE_DEMO2_PORT || '5003'"
      assert env =~ "VITE_DEMO3_PORT || '5050'"

      # config/dev.exs is still valid Elixir, with the three origins added.
      origins =
        tmp_dir
        |> Path.join("config/dev.exs")
        |> Config.Reader.read!(env: :dev)
        |> get_in([Mix.Project.config()[:app], :cors_origins])

      for port <- [5002, 5003, 5050], do: assert("http://localhost:#{port}" in origins)
    end

    test "a name that is not a JavaScript identifier is quoted", %{tmp_dir: tmp_dir} do
      gen(tmp_dir, ["admin-panel"])

      assert read(tmp_dir, "apps/admin-panel/vite.config.ts") =~
               ~s(env.APPS["admin-panel"].basename)

      env = read(tmp_dir, "packages/shared-components/src/env.ts")
      assert env =~ ~s("admin-panel": {)
      assert env =~ "VITE_ADMIN_PANEL_PORT"
      assert %{"name" => "rephi-admin-panel"} = json(tmp_dir, "apps/admin-panel/package.json")
    end
  end

  describe "an Astro site (--template example-astro)" do
    test "copies the site with its own name and port", %{tmp_dir: tmp_dir} do
      env_before = read(tmp_dir, "packages/shared-components/src/env.ts")

      gen(tmp_dir, ["site", "--template", "example-astro"])

      package = json(tmp_dir, "apps/site/package.json")
      assert package["name"] == "rephi-site"
      # Still a static site that Phoenix does not serve unless asked to.
      assert package["rephi"] == %{"copyToPhoenix" => false}

      assert read(tmp_dir, "apps/site/astro.config.ts") =~ "port: 4322"
      assert read(tmp_dir, "apps/site/wrangler.jsonc") =~ ~s("name": "rephi-site")
      assert read(tmp_dir, "apps/site/.env.example") =~ "ASTRO_BASE=/app/site"

      assert json(tmp_dir, "package.json")["scripts"]["site:build"] ==
               "yarn workspace rephi-site build"

      # Astro sites do not use the shared env's APPS.
      assert read(tmp_dir, "packages/shared-components/src/env.ts") == env_before
      assert read(tmp_dir, "config/dev.exs") =~ ~s("http://localhost:4322")
    end
  end

  describe "refusals change nothing" do
    test "invalid names", %{tmp_dir: tmp_dir} do
      before = snapshot(tmp_dir)

      assert gen_error(tmp_dir, ["Demo"]) =~ ~s[use lowercase letters ("demo")]
      assert gen_error(tmp_dir, ["shared"]) =~ "reserved"

      for name <- ["../x", "_x", "a b", "a.b", "", String.duplicate("a", 65)] do
        assert gen_error(tmp_dir, [name]) =~ "Invalid app name"
      end

      assert snapshot(tmp_dir) == before
    end

    test "an app that already exists", %{tmp_dir: tmp_dir} do
      assert gen_error(tmp_dir, ["example"]) =~ "apps/example already exists"

      gen(tmp_dir, ["demo"])
      after_first = snapshot(tmp_dir)

      assert gen_error(tmp_dir, ["demo"]) =~ "apps/demo already exists"
      assert snapshot(tmp_dir) == after_first
    end

    test "a script or package name that is taken", %{tmp_dir: tmp_dir} do
      package = json(tmp_dir, "package.json")
      scripts = Map.put(package["scripts"], "docs:dev", "echo")

      File.write!(
        Path.join(tmp_dir, "package.json"),
        Jason.encode!(Map.put(package, "scripts", scripts))
      )

      assert gen_error(tmp_dir, ["docs"]) =~ "docs:dev already exist"

      File.mkdir_p!(Path.join(tmp_dir, "packages/other"))
      File.write!(Path.join(tmp_dir, "packages/other/package.json"), ~s({"name": "rephi-other"}))
      assert gen_error(tmp_dir, ["other"]) =~ "rephi-other is already used"
    end

    test "bad options and arguments", %{tmp_dir: tmp_dir} do
      before = snapshot(tmp_dir)

      assert gen_error(tmp_dir, []) =~ "Usage: mix rephi.gen.frontend"
      assert gen_error(tmp_dir, ["a", "b"]) =~ "Usage: mix rephi.gen.frontend"
      assert gen_error(tmp_dir, ["-x"]) =~ "-x"
      assert gen_error(tmp_dir, ["a", "--bogus"]) =~ "--bogus"
      assert gen_error(tmp_dir, ["a", "--template", "nope"]) =~ "Template app apps/nope not found"
      assert gen_error(tmp_dir, ["a", "--template", "../x"]) =~ "Invalid template name"
      assert gen_error(tmp_dir, ["a", "--port", "5001"]) =~ "Port 5001 is already used"
      assert gen_error(tmp_dir, ["a", "--port", "80"]) =~ "between 1024 and 65535"

      assert snapshot(tmp_dir) == before
    end

    test "a template the task does not understand", %{tmp_dir: tmp_dir} do
      File.mkdir_p!(Path.join(tmp_dir, "apps/plain"))
      File.write!(Path.join(tmp_dir, "apps/plain/package.json"), ~s({"name": "rephi-plain"}))

      assert gen_error(tmp_dir, ["a", "--template", "plain"]) =~
               "neither a Vite app"
    end

    test "a shared env.ts without the template's entry", %{tmp_dir: tmp_dir} do
      env = Path.join(tmp_dir, "packages/shared-components/src/env.ts")
      File.write!(env, String.replace(File.read!(env), "example: {", "renamed: {"))
      before = snapshot(tmp_dir)

      assert gen_error(tmp_dir, ["demo"]) =~ "Could not find the example entry"
      assert snapshot(tmp_dir) == before
      refute File.exists?(Path.join(tmp_dir, "apps/demo"))
    end

    test "a template whose config does not use the shared env", %{tmp_dir: tmp_dir} do
      vite = Path.join(tmp_dir, "apps/example/vite.config.ts")
      File.write!(vite, String.replace(File.read!(vite), "env.APPS.example", "settings"))
      before = snapshot(tmp_dir)

      assert gen_error(tmp_dir, ["demo"]) =~ ~s[Could not find "env.APPS.example"]
      assert snapshot(tmp_dir) == before
    end
  end

  defp collect_info(acc \\ []) do
    receive do
      {:mix_shell, :info, [message]} when is_binary(message) -> collect_info([message | acc])
      {:mix_shell, :info, _} -> collect_info(acc)
    after
      0 -> Enum.reverse(acc)
    end
  end
end
