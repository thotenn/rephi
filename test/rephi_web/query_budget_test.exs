defmodule RephiWeb.QueryBudgetTest do
  @moduledoc """
  RBAC-01 / RBAC-10: what a request costs in SQL queries. The authorization
  of a request is loaded once (`RephiWeb.Auth.Pipeline`): the user, then its
  access, whatever the depth of the role hierarchy. If one of these numbers
  grows, something started querying per check again.
  """
  use RephiWeb.ConnCase, async: true

  import Rephi.QueryCounter

  alias Rephi.{Authorization, Seeds}
  alias RephiWeb.Auth.AuthorizationPlug

  # user + access
  @authenticated 2

  setup %{conn: conn} do
    {:ok, _} = Seeds.run(admin_email: nil, admin_password: nil, admin: :optional)
    {admin, token} = create_user_with_token_and(roles: ["admin"])
    {:ok, admin: admin, as_admin: authenticate_conn(conn, token)}
  end

  defp cost(fun) do
    {conn, count} = count_queries(fun)
    assert conn.status in 200..299, "unexpected #{conn.status}: #{conn.resp_body}"
    count
  end

  test "login and /api/me", %{conn: conn, admin: admin, as_admin: as_admin} do
    # user by email + access (shared by the response and the token claims)
    assert cost(fn ->
             post(conn, ~p"/api/users/login", %{email: admin.email, password: "password123"})
           end) == 2

    assert cost(fn -> get(as_admin, ~p"/api/me") end) == @authenticated
  end

  test "registration", %{conn: conn} do
    # insert user + default role lookup + insert user_role + access
    assert cost(fn ->
             post(conn, ~p"/api/users/register", %{
               email: "new@example.com",
               password: "password123"
             })
           end) == 4
  end

  test "protected endpoints", %{as_admin: conn} do
    role = Authorization.get_role_by_slug("manager")
    permission = Authorization.get_permission_by_slug("users:view")

    # + count + page
    assert cost(fn -> get(conn, ~p"/api/roles") end) == @authenticated + 2
    assert cost(fn -> get(conn, ~p"/api/permissions") end) == @authenticated + 2
    # + role + its permissions with their sources
    assert cost(fn -> get(conn, ~p"/api/roles/#{role}") end) == @authenticated + 2
    assert cost(fn -> get(conn, ~p"/api/roles/#{role}/permissions") end) == @authenticated + 2
    # + permission
    assert cost(fn -> get(conn, ~p"/api/permissions/#{permission}") end) == @authenticated + 1
  end

  test "the user list does not grow with the number of users", %{as_admin: conn} do
    # + count + page + roles + direct permissions
    assert cost(fn -> get(conn, ~p"/api/users") end) == @authenticated + 4

    for _ <- 1..20, do: create_user_with_token_and(roles: ["user"], permissions: ["x:y"])

    assert cost(fn -> get(conn, ~p"/api/users") end) == @authenticated + 4
  end

  test "the hierarchy and the permissions of a user", %{as_admin: conn, admin: admin} do
    manager = Authorization.get_role_by_slug("manager")

    # + role + its links
    assert cost(fn -> get(conn, ~p"/api/roles/#{manager}/parents") end) == @authenticated + 2
    assert cost(fn -> get(conn, ~p"/api/roles/#{manager}/children") end) == @authenticated + 2

    # + user + direct grants + permissions through roles (whole hierarchy)
    assert cost(fn -> get(conn, ~p"/api/users/#{admin}/permissions") end) == @authenticated + 3

    roles = for _ <- 1..5, do: create_role()

    for [parent, child] <- Enum.chunk_every(roles, 2, 1, :discard) do
      {:ok, _} = Authorization.assign_parent_role(child, parent)
      {:ok, _} = Authorization.assign_parent_role(manager, parent)
    end

    for role <- roles,
        do: {:ok, _} = Authorization.assign_permission_to_role(role, create_permission())

    {:ok, _} = Authorization.assign_role_to_user(admin, List.last(roles))

    for _ <- 1..5,
        do: {:ok, _} = Authorization.assign_permission_to_user(admin, create_permission())

    assert cost(fn -> get(conn, ~p"/api/roles/#{manager}/parents") end) == @authenticated + 2
    assert cost(fn -> get(conn, ~p"/api/roles/#{hd(roles)}/children") end) == @authenticated + 2
    assert cost(fn -> get(conn, ~p"/api/users/#{admin}/permissions") end) == @authenticated + 3
  end

  test "the depth of the hierarchy does not matter", %{conn: conn} do
    roles = for _ <- 1..6, do: create_role()

    for [parent, child] <- Enum.chunk_every(roles, 2, 1, :discard) do
      {:ok, _} = Authorization.assign_parent_role(child, parent)
    end

    {:ok, _} =
      Authorization.assign_permission_to_role(
        hd(roles),
        Authorization.get_permission_by_slug("roles:view")
      )

    user = create_user(%{password: "password123"})
    {:ok, _} = Authorization.assign_role_to_user(user, List.last(roles))

    assert cost(fn ->
             post(conn, ~p"/api/users/login", %{email: user.email, password: "password123"})
           end) == 2

    {:ok, token, _} = RephiWeb.Auth.Guardian.encode_and_sign(user)
    conn = authenticate_conn(conn, token)

    assert cost(fn -> get(conn, ~p"/api/me") end) == @authenticated
    assert cost(fn -> get(conn, ~p"/api/roles") end) == @authenticated + 2
  end

  describe "AuthorizationPlug" do
    test "every form costs nothing with the access loaded, one query without", %{admin: admin} do
      checks = [
        {:permission, "roles:view"},
        {:role, "user"},
        {:any_permission, ["nope:nope", "roles:view"]},
        {:all_permissions, ["roles:view", "roles:edit", "users:view"]}
      ]

      for check <- checks do
        conn = build_conn() |> assign(:current_user, admin)

        assert {%{halted: false} = conn, 1} =
                 count_queries(fn -> AuthorizationPlug.call(conn, check) end)

        assert {%{halted: false}, 0} =
                 count_queries(fn -> AuthorizationPlug.call(conn, check) end)
      end
    end
  end
end
