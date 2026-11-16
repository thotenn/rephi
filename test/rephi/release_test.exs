defmodule Rephi.ReleaseTest do
  use Rephi.DataCase, async: false

  import ExUnit.CaptureIO
  import Rephi.AuthTestHelpers, only: [put_app_env: 2]

  alias Rephi.Release

  test "migrate/0 runs the pending migrations (none left in the test database)" do
    ExUnit.CaptureLog.capture_log(fn -> assert Release.migrate() == :ok end)
  end

  test "seed/0 seeds roles and permissions and reports the administrator" do
    output = capture_io(fn -> assert Release.seed() == :ok end)

    assert output =~ "Seeded the default roles and permissions."
    assert output =~ "Administrator: none (ADMIN_EMAIL / ADMIN_PASSWORD are not set)"
    assert Rephi.Authorization.get_role_by_slug("admin").is_system
  end

  test "seed/0 reports the administrator and the grants the seed no longer makes" do
    put_app_env(Rephi.Seeds, admin: :default)

    assert capture_io(&Release.seed/0) =~
             "Administrator: admin@admin.com (the well-known development administrator)"

    user = Rephi.Authorization.get_role_by_slug("user")
    permission = Rephi.Authorization.get_permission_by_slug("system:manage")
    {:ok, _} = Rephi.Authorization.assign_permission_to_role(user, permission)

    with_env(%{"ADMIN_EMAIL" => "owner@example.com", "ADMIN_PASSWORD" => "a-long-password"}, fn ->
      output = capture_io(&Release.seed/0)
      assert output =~ "Administrator: owner@example.com (created)"
      assert output =~ "NOTICE: role user holds system:manage"

      assert capture_io(&Release.seed/0) =~
               "Administrator: owner@example.com (already existed, unchanged)"
    end)
  end

  defp with_env(vars, fun) do
    previous = Map.new(vars, fn {name, _} -> {name, System.get_env(name)} end)
    System.put_env(vars)

    try do
      fun.()
    after
      Enum.each(previous, fn
        {name, nil} -> System.delete_env(name)
        {name, value} -> System.put_env(name, value)
      end)
    end
  end

  test "seed/0 raises when seeding fails" do
    put_app_env(Rephi.Seeds, admin: :required)

    assert_raise RuntimeError, ~r/seeding failed: .*ADMIN_EMAIL/, fn ->
      capture_io(&Release.seed/0)
    end
  end
end
