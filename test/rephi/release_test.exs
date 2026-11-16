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
    # config/test.exs: no administrator without ADMIN_EMAIL / ADMIN_PASSWORD.
    assert output =~ "Administrator: none (ADMIN_EMAIL / ADMIN_PASSWORD are not set)"
    assert Rephi.Authorization.get_role_by_slug("admin").is_system
  end

  test "seed/0 raises when seeding fails" do
    put_app_env(Rephi.Seeds, admin: :required)

    assert_raise RuntimeError, ~r/seeding failed: .*ADMIN_EMAIL/, fn ->
      capture_io(&Release.seed/0)
    end
  end
end
