defmodule RephiWeb.FallbackControllerTest do
  use RephiWeb.ConnCase, async: true

  alias RephiWeb.FallbackController

  @statuses [
    bad_request: {400, "Bad Request"},
    unauthorized: {401, "Unauthorized"},
    forbidden: {403, "Forbidden"},
    not_found: {404, "Not Found"},
    conflict: {409, "Conflict"},
    unprocessable_entity: {422, "Unprocessable Content"},
    service_unavailable: {503, "Service Unavailable"}
  ]

  for {status, {code, message}} <- @statuses do
    test "{:error, #{inspect(status)}} renders a #{code} with the status message", %{conn: conn} do
      conn = FallbackController.call(conn, {:error, unquote(status)})

      assert error_detail(conn, unquote(code)) == unquote(message)
    end
  end

  test "{:error, status, message} renders the message as the detail", %{conn: conn} do
    conn = FallbackController.call(conn, {:error, :unauthorized, "Invalid email or password"})

    assert error_detail(conn, 401) == "Invalid email or password"
  end

  test "{:error, changeset} renders a 422 with the errors of every field", %{conn: conn} do
    changeset =
      {%{}, %{name: :string, slug: :string}}
      |> Ecto.Changeset.cast(%{"slug" => "Bad Slug"}, [:name, :slug])
      |> Ecto.Changeset.validate_required([:name])
      |> Ecto.Changeset.validate_format(:slug, ~r/\A[a-z]+\z/)

    conn = FallbackController.call(conn, {:error, changeset})

    assert json_response(conn, 422) == %{
             "errors" => %{"name" => ["can't be blank"], "slug" => ["has invalid format"]}
           }
  end

  test "does not need the request to have gone through a pipeline", %{conn: conn} do
    # Plugs call it before the `:api` pipeline has set a format.
    assert conn.private[:phoenix_format] == nil

    conn = FallbackController.call(conn, {:error, :forbidden})

    assert error_detail(conn, 403) == "Forbidden"
    assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
  end

  test "domain errors have their own status and message", %{conn: conn} do
    for {reason, {status, message}} <- RephiWeb.FallbackController.domain_errors() do
      conn = RephiWeb.FallbackController.call(conn, {:error, reason})

      assert conn.status == Plug.Conn.Status.code(status), "#{reason}"
      assert Jason.decode!(conn.resp_body) == %{"errors" => %{"detail" => message}}
    end
  end
end
