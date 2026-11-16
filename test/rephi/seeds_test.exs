defmodule Rephi.SeedsTest do
  @moduledoc "SEC-07 / RBAC-11."
  # One test changes the application environment
  use Rephi.DataCase, async: false

  alias Rephi.{Accounts, Authorization, Seeds}
  alias Rephi.Authorization.{Permission, Role}

  @admin [admin_email: "Owner@Example.com", admin_password: "a-long-admin-password"]
  @no_env [admin_email: nil, admin_password: nil]

  defp counts do
    for table <- ~w(roles permissions role_roles role_permissions user_roles users), into: %{} do
      {table, Repo.aggregate(table, :count)}
    end
  end

  test "creates the roles, permissions, hierarchy and admin" do
    assert {:ok, %{admin: {:created, "owner@example.com"}}} = Seeds.run(@admin)

    assert %{
             "roles" => 3,
             "permissions" => 19,
             "role_roles" => 2,
             "users" => 1,
             "user_roles" => 1
           } = counts()

    admin = Accounts.get_user_by_email("owner@example.com")
    assert Authorization.has_role?(admin, "admin")
    assert Authorization.can?(admin, "notifications:broadcast")
    assert {:ok, _} = Accounts.authenticate_user("owner@example.com", "a-long-admin-password")
  end

  test "only admin is granted notifications:broadcast" do
    {:ok, _} = Seeds.run(@admin ++ [admin: :optional])

    permission = Authorization.get_permission_by_slug("notifications:broadcast")

    granted =
      for role <- Repo.all(Role),
          Authorization.role_has_permission?(role, permission),
          do: role.slug

    assert granted == ["admin"]
  end

  test "only admin is granted users:reset_password, as a system permission" do
    {:ok, _} = Seeds.run(@admin ++ [admin: :optional])

    permission = Authorization.get_permission_by_slug("users:reset_password")
    assert permission.is_system

    granted =
      for role <- Repo.all(Role),
          Authorization.role_has_permission?(role, permission),
          do: role.slug

    assert granted == ["admin"]
  end

  test "an existing database gets users:reset_password, and nothing else changes" do
    {:ok, _} = Seeds.run(@admin)
    before = counts()

    Repo.delete!(Authorization.get_permission_by_slug("users:reset_password"))
    assert counts()["permissions"] == before["permissions"] - 1

    {:ok, _} = Seeds.run(@admin)
    {:ok, _} = Seeds.run(@admin)

    assert counts() == before

    assert Authorization.can?(
             Accounts.get_user_by_email("owner@example.com"),
             "users:reset_password"
           )
  end

  test "marks the links of the default hierarchy as system links, existing ones too" do
    {:ok, _} = Seeds.run(@admin)

    assert Repo.all(
             from rr in "role_roles",
               join: c in Role,
               on: c.id == rr.child_role_id,
               join: p in Role,
               on: p.id == rr.parent_role_id,
               order_by: c.slug,
               select: {c.slug, p.slug, rr.is_system}
           ) == [{"admin", "manager", true}, {"manager", "user", true}]

    Repo.update_all("role_roles", set: [is_system: false])
    {:ok, _} = Seeds.run(@admin)

    assert Repo.all(from rr in "role_roles", select: rr.is_system) == [true, true]
  end

  test "is idempotent" do
    {:ok, _} = Seeds.run(@admin)
    before = counts()

    assert {:ok, %{admin: {:existing, "owner@example.com"}}} = Seeds.run(@admin)
    assert counts() == before
  end

  test "puts back what is missing and leaves the rest alone" do
    {:ok, _} = Seeds.run(@admin)
    before = counts()

    Repo.delete!(Authorization.get_permission_by_slug("notifications:broadcast"))

    {:ok, _} =
      Authorization.update_role(Authorization.get_role_by_slug("user"), %{name: "Member"})

    {:ok, _} = Seeds.run(@admin)

    assert counts() == before
    assert Authorization.get_role_by_slug("user").name == "Member"

    assert Authorization.can?(
             Accounts.get_user_by_email("owner@example.com"),
             "notifications:broadcast"
           )
  end

  test "never changes the password of an existing admin" do
    {:ok, _} = Seeds.run(@admin)

    assert {:ok, %{admin: {:existing, _}}} =
             Seeds.run(admin_email: "owner@example.com", admin_password: "another-password")

    assert {:ok, _} = Accounts.authenticate_user("owner@example.com", "a-long-admin-password")
  end

  test "promotes an existing user to admin" do
    {:ok, user} = Accounts.create_user(%{email: "owner@example.com", password: "password123"})
    assert {:ok, %{admin: {:existing, _}}} = Seeds.run(@admin)
    assert Authorization.has_role?(user, "admin")
  end

  describe "without ADMIN_EMAIL / ADMIN_PASSWORD" do
    test "where an admin is required, nothing at all is seeded" do
      assert {:error, message} = Seeds.run(@no_env ++ [admin: :required])
      assert message =~ "ADMIN_EMAIL and ADMIN_PASSWORD are required"
      assert Repo.aggregate(Role, :count) == 0
      assert Repo.aggregate(Permission, :count) == 0
    end

    test "required is the default when nothing is configured" do
      previous = Application.get_env(:rephi, Seeds)
      Application.delete_env(:rephi, Seeds)
      on_exit(fn -> Application.put_env(:rephi, Seeds, previous) end)

      assert {:error, _} = Seeds.run(@no_env)
    end

    test "in development, the well-known admin is used and reported as such" do
      assert {:ok, %{admin: {:default_created, "admin@admin.com"}}} =
               Seeds.run(@no_env ++ [admin: :default])

      assert {:ok, %{admin: {:default_existing, "admin@admin.com"}}} =
               Seeds.run(@no_env ++ [admin: :default])
    end

    test "where it is optional (the test environment), no admin is created" do
      assert {:ok, %{admin: :skipped}} = Seeds.run(@no_env)
      assert Repo.aggregate("users", :count) == 0
      assert Accounts.get_user_by_email("admin@admin.com") == nil
    end
  end

  describe "RBAC-04 / RBAC-07" do
    test "every seeded role and permission is a system record" do
      {:ok, _} = Seeds.run(@admin)

      assert Repo.all(from r in Role, where: not r.is_system) == []
      assert Repo.all(from p in Permission, where: not p.is_system) == []
    end

    test "rows that already existed with a seeded slug are marked too, and nothing else changes" do
      {:ok, role} = Authorization.create_role(%{name: "Members", slug: "user"})
      {:ok, custom} = Authorization.create_role(%{name: "Custom", slug: "custom"})
      refute role.is_system

      {:ok, _} = Seeds.run(@admin)

      assert %Role{is_system: true, name: "Members"} = Authorization.get_role_by_slug("user")
      refute Authorization.get_role(custom.id).is_system
    end

    test "the user role holds no permission over other users" do
      {:ok, _} = Seeds.run(@admin)

      granted =
        for slug <- ~w(users:view users:create users:edit users:delete),
            role <- ~w(user manager admin),
            Authorization.role_has_permission?(Authorization.get_role_by_slug(role), slug),
            do: {role, slug}

      refute Enum.any?(granted, &match?({"user", _}, &1))
      assert {"manager", "users:view"} in granted
      assert {"admin", "users:delete"} in granted
      refute {"manager", "users:delete"} in granted
    end

    test "grants the seed no longer makes are reported, never revoked" do
      {:ok, %{stale_grants: []}} = Seeds.run(@admin)

      # What an older seed did: user -> users:view
      {:ok, _} =
        Authorization.assign_permission_to_role(
          Authorization.get_role_by_slug("user"),
          Authorization.get_permission_by_slug("users:view")
        )

      assert {:ok, %{stale_grants: [{"user", "users:view"}]}} = Seeds.run(@admin)

      assert Authorization.role_has_permission?(
               Authorization.get_role_by_slug("user"),
               "users:view"
             )
    end
  end

  test "only one of the two variables is an error" do
    assert {:error, "set both ADMIN_EMAIL and ADMIN_PASSWORD, or neither"} =
             Seeds.run(admin_email: "owner@example.com", admin_password: nil)
  end

  test "an invalid admin rolls everything back" do
    assert {:error, message} =
             Seeds.run(admin_email: "owner@example.com", admin_password: "short")

    assert message =~ "password should be at least 8 character(s)"
    assert Repo.aggregate(Role, :count) == 0
  end
end
