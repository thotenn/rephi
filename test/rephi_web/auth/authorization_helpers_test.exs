defmodule RephiWeb.Auth.AuthorizationHelpersTest do
  @moduledoc "RBAC-10: the helpers read the access loaded for the request."
  use RephiWeb.ConnCase, async: true

  import Rephi.QueryCounter
  import RephiWeb.Auth.AuthorizationHelpers

  alias Rephi.Authorization

  setup do
    {user, _token} = create_user_with_token_and(roles: ["editor"], permissions: ["posts:edit"])
    {:ok, user: user}
  end

  test "with the access in the conn, no query", %{conn: conn, user: user} do
    conn =
      conn
      |> assign(:current_user, user)
      |> assign(:current_access, Authorization.load_access(user))

    assert {true, 0} == count_queries(fn -> can?(conn, "posts:edit") end)
    assert {true, 0} == count_queries(fn -> has_role?(conn, "editor") end)
    assert {true, 0} == count_queries(fn -> can_any?(conn, ["x:y", "posts:edit"]) end)
    assert {false, 0} == count_queries(fn -> can_all?(conn, ["x:y", "posts:edit"]) end)
    assert %{user_id: id} = current_access(conn)
    assert id == user.id
  end

  test "with only a user, the access is loaded", %{conn: conn, user: user} do
    conn = assign(conn, :current_user, user)
    assert {true, 1} == count_queries(fn -> can?(conn, "posts:edit") end)
  end

  test "an access of another user is not trusted", %{conn: conn, user: user} do
    other = create_user()

    conn =
      conn
      |> assign(:current_user, other)
      |> assign(:current_access, Authorization.load_access(user))

    refute can?(conn, "posts:edit")
  end

  test "nobody signed in: everything is false", %{conn: conn} do
    assert current_access(conn) == nil
    refute can?(conn, "posts:edit")
    refute has_role?(conn, "editor")
    refute can_any?(conn, ["posts:edit"])
    refute can_all?(conn, [])
  end
end
