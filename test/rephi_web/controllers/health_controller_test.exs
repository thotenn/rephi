defmodule RephiWeb.HealthControllerTest do
  use RephiWeb.ConnCase, async: true

  describe "GET /api/health" do
    test "answers 200 without authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/health")

      assert json_response(conn, 200) == %{"data" => %{"status" => "ok"}}
    end
  end

  describe "GET /api/health/ready" do
    test "answers 200 when the database answers", %{conn: conn} do
      conn = get(conn, ~p"/api/health/ready")

      assert json_response(conn, 200) == %{
               "data" => %{"status" => "ok", "checks" => %{"database" => "ok"}}
             }
    end
  end
end

defmodule RephiWeb.HealthControllerDatabaseDownTest do
  # No sandbox connection is checked out here, so this process (and the task
  # the readiness check runs in) cannot reach the database: the closest thing
  # to an outage that a test can produce without stopping the repo.
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Rephi.AuthTestHelpers, only: [error_detail: 2]

  @endpoint RephiWeb.Endpoint

  test "Rephi.Health.check_database/1 reports the database as unavailable" do
    assert Rephi.Health.check_database(200) == {:error, :database_unavailable}
  end

  test "GET /api/health/ready answers 503 in the error envelope" do
    conn = get(build_conn(), "/api/health/ready")

    assert error_detail(conn, 503) == "Database unavailable"
  end

  test "GET /api/health still answers 200" do
    conn = get(build_conn(), "/api/health")

    assert json_response(conn, 200) == %{"data" => %{"status" => "ok"}}
  end
end
