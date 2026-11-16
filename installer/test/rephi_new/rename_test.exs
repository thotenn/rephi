defmodule RephiNew.RenameTest do
  use ExUnit.Case, async: true

  alias RephiNew.Rename

  @names %{app: "acme_hub", module: "AcmeHub"}

  defp rename(text, names \\ @names), do: Rename.text(text, names)

  describe "text/2" do
    test "renames modules, the application and derived names" do
      assert rename("defmodule Rephi.Accounts do") == "defmodule AcmeHub.Accounts do"
      assert rename("alias RephiWeb.Endpoint") == "alias AcmeHubWeb.Endpoint"
      assert rename("%Rephi.Accounts.User{}") == "%AcmeHub.Accounts.User{}"
      assert rename("config :rephi, Rephi.Repo,") == "config :acme_hub, AcmeHub.Repo,"
      assert rename(~s(key: "_rephi_key")) == ~s(key: "_acme_hub_key")
      assert rename(~s("rephi_dev" "rephi_test")) == ~s("acme_hub_dev" "acme_hub_test")

      assert rename("lib/rephi_web/router.ex lib/rephi.ex") ==
               "lib/acme_hub_web/router.ex lib/acme_hub.ex"

      assert rename(~s(issuer: "rephi")) == ~s(issuer: "acme_hub")
      assert rename("bin/rephi start") == "bin/acme_hub start"
      assert rename("REPHI_ENV") == "ACME_HUB_ENV"
      assert rename("Environment variables for Rephi.") == "Environment variables for AcmeHub."
    end

    test "renames in one pass: a name that contains the template's is not renamed twice" do
      names = %{app: "morephi", module: "Morephi"}

      assert rename("Rephi.Application rephi_web :rephi", names) ==
               "Morephi.Application morephi_web :morephi"

      assert rename("Morephi morephi", @names) == "Morephi morephi"
      assert rename("rephix xrephi Xrephi") == "rephix xrephi Xrephi"
    end

    test "keeps the Mix task namespace" do
      assert rename("defmodule Mix.Tasks.Rephi.Gen.Frontend do") ==
               "defmodule Mix.Tasks.Rephi.Gen.Frontend do"

      assert rename("mix rephi.gen.frontend NAME and mix rephi.new PATH") ==
               "mix rephi.gen.frontend NAME and mix rephi.new PATH"
    end

    test "keeps npm names and the frontends' marker field" do
      for text <- [
            "@rephi/shared-components",
            "yarn workspace rephi-example dev",
            ~s("rephi": { "copyToPhoenix": false }),
            "rephi.copyToPhoenix",
            "import { env } from '~/lib/rephi'"
          ] do
        assert rename(text) == text
      end
    end

    test "keeps URLs" do
      text = "See https://github.com/thotenn/rephi (Rephi) and http://rephi.example.com/x."

      assert rename(text) ==
               "See https://github.com/thotenn/rephi (AcmeHub) and http://rephi.example.com/x."
    end

    test "uses the given module for dotted names" do
      assert rename("RephiWeb Rephi.Repo", %{app: "hub", module: "Acme.Hub"}) ==
               "Acme.HubWeb Acme.Hub.Repo"
    end
  end

  test "path/2 renames every segment but Mix task files" do
    assert Rename.path("lib/rephi_web/endpoint.ex", @names) == "lib/acme_hub_web/endpoint.ex"
    assert Rename.path("lib/rephi.ex", @names) == "lib/acme_hub.ex"
    assert Rename.path("test/rephi/seeds_test.exs", @names) == "test/acme_hub/seeds_test.exs"

    assert Rename.path("lib/mix/tasks/rephi.gen.frontend.ex", @names) ==
             "lib/mix/tasks/rephi.gen.frontend.ex"

    assert Rename.path("priv/repo/seeds.exs", @names) == "priv/repo/seeds.exs"
  end

  describe "validate_app/1" do
    test "accepts what Mix accepts as an application name" do
      for app <- ~w(acme acme_hub a1 rephi morephi) do
        assert Rename.validate_app(app) == :ok
      end
    end

    test "rejects invalid and reserved names" do
      for app <- ["My-App", "1app", "_app", "app!", "Acme", "", "acme hub"] do
        assert {:error, message} = Rename.validate_app(app)
        assert message =~ "Application name must start with a letter"
      end

      for app <- ~w(phoenix ecto mix elixir) do
        assert {:error, message} = Rename.validate_app(app)
        assert message =~ "name of a dependency"
      end
    end
  end

  describe "validate_module/1" do
    test "accepts aliases" do
      for module <- ~w(AcmeHub Acme.Hub A1) do
        assert Rename.validate_module(module) == :ok
      end
    end

    test "rejects invalid aliases and existing modules" do
      for module <- ["acme", "Acme-Hub", "Acme.", ".Acme", "Acme..Hub", "Acme Hub"] do
        assert {:error, message} = Rename.validate_module(module)
        assert message =~ "valid Elixir alias"
      end

      for module <- ~w(Mix Enum) do
        assert {:error, message} = Rename.validate_module(module)
        assert message =~ "already taken"
      end
    end
  end
end
