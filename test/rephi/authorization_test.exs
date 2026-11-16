defmodule Rephi.AuthorizationTest do
  @moduledoc "The `Rephi.Authorization` context (RBAC-01 … RBAC-22)."
  # Some tests run concurrent tasks against the shared sandbox connection.
  use Rephi.DataCase, async: false

  import Rephi.AuthTestHelpers
  import Rephi.QueryCounter

  alias Rephi.{Accounts, Authorization}
  alias Rephi.Accounts.User
  alias Rephi.Authorization.{Access, Permission, Role, RoleRole, UserRole}

  defp chain(depth) do
    roles =
      for _ <- 1..depth do
        role = create_role()
        {:ok, _} = Authorization.assign_permission_to_role(role, create_permission())
        role
      end

    for [parent, child] <- Enum.chunk_every(roles, 2, 1, :discard) do
      {:ok, _} = Authorization.assign_parent_role(child, parent)
    end

    slugs = Enum.map(roles, &(&1 |> Authorization.get_role_permission_sources() |> own_slug()))
    {roles, slugs}
  end

  defp own_slug(%{direct: [permission]}), do: permission.slug

  defp user_with_role(role) do
    user = create_user()
    {:ok, _} = Authorization.assign_role_to_user(user, role)
    user
  end

  defp seed_admin_role do
    role = create_role(%{slug: Authorization.admin_role_slug(), name: "Administrator"})
    role
  end

  describe "effective permissions in one query (RBAC-01, RBAC-10)" do
    for depth <- [1, 3, 6] do
      test "a chain of #{depth} role(s)" do
        {roles, slugs} = chain(unquote(depth))
        user = user_with_role(List.last(roles))

        for slug <- slugs do
          assert {true, 1} == count_queries(fn -> Authorization.can?(user, slug) end)
        end

        assert {permissions, 1} =
                 count_queries(fn -> Authorization.get_user_permissions(user) end)

        assert Enum.map(permissions, & &1.slug) == Enum.sort(slugs)

        assert {role_permissions, 1} =
                 count_queries(fn -> Authorization.get_role_permissions(List.last(roles)) end)

        assert Enum.map(role_permissions, & &1.slug) == Enum.sort(slugs)

        assert {%Access{} = access, 1} = count_queries(fn -> Authorization.load_access(user) end)
        assert MapSet.equal?(access.permission_slugs, MapSet.new(slugs))
        assert MapSet.equal?(access.role_slugs, MapSet.new(roles, & &1.slug))
        assert Enum.map(access.roles, & &1.slug) == [List.last(roles).slug]
      end
    end

    test "a diamond: the common ancestor's permission arrives once" do
      [top, left, right, bottom] = for _ <- 1..4, do: create_role()
      shared = create_permission()
      {:ok, _} = Authorization.assign_permission_to_role(top, shared)
      {:ok, _} = Authorization.assign_parent_role(left, top)
      {:ok, _} = Authorization.assign_parent_role(right, top)
      {:ok, _} = Authorization.assign_parent_role(bottom, left)
      {:ok, _} = Authorization.assign_parent_role(bottom, right)

      user = user_with_role(bottom)

      assert {true, 1} == count_queries(fn -> Authorization.can?(user, shared.slug) end)
      assert [%Permission{id: id}] = Authorization.get_user_permissions(user)
      assert id == shared.id
      assert %Access{permissions: [%{slug: slug}]} = Authorization.load_access(user)
      assert slug == shared.slug
    end

    test "direct permissions, roles, inheritance and nothing give the same answers from a user and from its access" do
      {[parent, child], [parent_slug, child_slug]} = chain(2)
      direct = create_permission()
      unrelated = create_permission()

      users = %{
        child_role: user_with_role(child),
        parent_role: user_with_role(parent),
        direct: create_user() |> tap(&Authorization.assign_permission_to_user(&1, direct)),
        nothing: create_user()
      }

      expected = %{
        child_role: [parent_slug, child_slug],
        parent_role: [parent_slug],
        direct: [direct.slug],
        nothing: []
      }

      for {name, user} <- users,
          access = Authorization.load_access(user),
          slug <- [parent_slug, child_slug, direct.slug, unrelated.slug, "nope:nope"] do
        allowed = slug in expected[name]
        assert Authorization.can?(user, slug) == allowed, "#{name} #{slug}"
        assert Authorization.can?(access, slug) == allowed, "#{name} #{slug} (access)"
      end
    end

    test "an access answers without querying" do
      {[role], [slug]} = chain(1)
      access = role |> user_with_role() |> Authorization.load_access()

      assert {true, 0} == count_queries(fn -> Authorization.can?(access, slug) end)
      assert {true, 0} == count_queries(fn -> Authorization.has_role?(access, role.slug) end)
      assert {true, 0} == count_queries(fn -> Authorization.can_all?(access, [slug, slug]) end)
      assert {false, 0} == count_queries(fn -> Authorization.can_any?(access, ["x:y"]) end)
    end
  end

  describe "a struct loaded before a change (RBAC-03)" do
    test "can? and has_role? see the change and agree" do
      {[role], [slug]} = chain(1)
      user = create_user()
      loaded = user.id |> Accounts.get_user() |> Accounts.preload_grants()
      assert loaded.roles == []

      {:ok, _} = Authorization.assign_role_to_user(user, role)
      assert Authorization.can?(loaded, slug)
      assert Authorization.has_role?(loaded, role.slug)
      assert [%Role{}] = Authorization.get_user_roles(loaded)

      loaded = Accounts.preload_grants(loaded)
      :ok = Authorization.remove_role_from_user(user, role)
      refute Authorization.can?(loaded, slug)
      refute Authorization.has_role?(loaded, role.slug)
      assert Authorization.get_user_roles(loaded) == []
    end
  end

  describe "can_any?/2 and can_all?/2 (RBAC-10)" do
    setup do
      {[role], [slug]} = chain(1)
      {:ok, user: user_with_role(role), slug: slug}
    end

    test "one query for a user, whatever the number of slugs", %{user: user, slug: slug} do
      assert {true, 1} == count_queries(fn -> Authorization.can_all?(user, [slug, slug]) end)
      assert {false, 1} == count_queries(fn -> Authorization.can_all?(user, [slug, "a:b"]) end)
      assert {true, 1} == count_queries(fn -> Authorization.can_any?(user, ["a:b", slug]) end)
      assert {false, 1} == count_queries(fn -> Authorization.can_any?(user, ["a:b", "c:d"]) end)
    end

    test "edge cases", %{user: user, slug: slug} do
      access = Authorization.load_access(user)

      for subject <- [user, access] do
        refute Authorization.can_any?(subject, [])
        assert Authorization.can_all?(subject, [])
        refute Authorization.can_all?(subject, [slug, :atom])
        assert Authorization.can_any?(subject, [:atom, slug])
        refute Authorization.can_any?(subject, "not a list")
      end

      refute Authorization.can_all?(nil, [])
      refute Authorization.can_any?(nil, [slug])
    end
  end

  describe "has_role?/2 and has_direct_role?/2 (RBAC-08)" do
    test "has_role? follows the hierarchy, has_direct_role? does not; one query each" do
      {[parent, child], _slugs} = chain(2)
      user = user_with_role(child)

      assert {true, 1} == count_queries(fn -> Authorization.has_role?(user, parent.slug) end)
      assert {true, 1} == count_queries(fn -> Authorization.has_role?(user, child) end)

      assert {false, 1} ==
               count_queries(fn -> Authorization.has_direct_role?(user, parent.slug) end)

      assert Authorization.has_direct_role?(user, child.slug)
      assert Authorization.has_direct_role?(user, child)

      access = Authorization.load_access(user)
      assert Authorization.has_role?(access, parent.slug)
      refute Authorization.has_direct_role?(access, parent.slug)
      assert Authorization.has_direct_role?(access, child)

      parent_user = user_with_role(parent)
      refute Authorization.has_role?(parent_user, child.slug)
    end
  end

  describe "invalid input never raises (RBAC-20)" do
    test "checks are false" do
      user = create_user()
      role = create_role()
      permission = create_permission()

      for subject <- [nil, %User{}, %User{id: "1"}, :user, %Access{}],
          thing <- ["roles:view", :"roles:view", nil, 1, permission, role] do
        refute Authorization.can?(subject, thing)
        refute Authorization.has_role?(subject, thing)
        refute Authorization.has_direct_role?(subject, thing)
      end

      for thing <- [:"roles:view", nil, 1, %Permission{}, %Role{}] do
        refute Authorization.can?(user, thing)
        refute Authorization.has_role?(user, thing)
        refute Authorization.role_has_permission?(role, thing)
      end

      refute Authorization.role_has_permission?(%Role{}, permission)
      refute Authorization.role_has_permission?(nil, "roles:view")
    end

    test "getters return nothing" do
      for subject <- [nil, %User{}] do
        assert Authorization.get_user_roles(subject) == []
        assert Authorization.get_user_permissions(subject) == []
        assert Authorization.load_access(subject) == %Access{}
      end

      assert Authorization.get_role_permissions(%Role{}) == []
      assert Authorization.get_role_permission_sources(nil) == %{direct: [], inherited: []}
      assert Authorization.get_role_by_slug(:admin) == nil
      assert Authorization.get_permission_by_slug(nil) == nil
    end

    test "writes with unsaved records are errors" do
      role = create_role()
      permission = create_permission()

      assert {:error, %Ecto.Changeset{}} = Authorization.assign_role_to_user(%User{}, role)
      assert {:error, :not_found} = Authorization.remove_role_from_user(%User{}, role)
      assert {:error, :not_found} = Authorization.remove_permission_from_user(nil, permission)
      assert {:error, :not_found} = Authorization.remove_permission_from_role(role, %Permission{})
      assert {:error, :not_found} = Authorization.remove_parent_role(role, %Role{})
      assert {:error, %Ecto.Changeset{}} = Authorization.assign_parent_role(role, %Role{})
    end
  end

  describe "role hierarchy cycles (RBAC-02)" do
    test "a role cannot be its own parent or ancestor" do
      [a, b, c] = for _ <- 1..3, do: create_role()

      assert {:error, changeset} = Authorization.assign_parent_role(a, a)
      assert %{parent_role_id: ["cannot be the role itself"]} = errors_on(changeset)

      {:ok, _} = Authorization.assign_parent_role(b, a)
      assert {:error, changeset} = Authorization.assign_parent_role(a, b)
      assert %{parent_role_id: ["would make the role inherit from itself"]} = errors_on(changeset)

      {:ok, _} = Authorization.assign_parent_role(c, b)
      assert {:error, _} = Authorization.assign_parent_role(a, c)

      assert {:error, changeset} = Authorization.assign_parent_role(b, a)
      assert %{parent_role_id: ["has already been taken"]} = errors_on(changeset)

      assert Repo.aggregate(RoleRole, :count) == 2
    end

    test "two concurrent links cannot close a cycle between them" do
      [a, b] = for _ <- 1..2, do: create_role()

      results =
        [{a, b}, {b, a}]
        |> Enum.map(fn {child, parent} ->
          Task.async(fn -> Authorization.assign_parent_role(child, parent) end)
        end)
        |> Task.await_many()

      assert [{:error, _}, {:ok, _}] = Enum.sort_by(results, &elem(&1, 0))
    end

    test "the database refuses a self link, even without the application" do
      role = create_role()
      now = DateTime.utc_now(:second)

      assert_raise Postgrex.Error, ~r/role_roles_no_self_parent/, fn ->
        Repo.insert_all(RoleRole, [
          %{parent_role_id: role.id, child_role_id: role.id, inserted_at: now, updated_at: now}
        ])
      end
    end

    test "reads terminate even if a cycle is inserted by hand" do
      {[a, b], [slug_a, slug_b]} = chain(2)
      c = create_role()
      now = DateTime.utc_now(:second)

      Repo.insert_all(RoleRole, [
        %{parent_role_id: b.id, child_role_id: a.id, inserted_at: now, updated_at: now},
        %{parent_role_id: a.id, child_role_id: c.id, inserted_at: now, updated_at: now}
      ])

      user = user_with_role(c)

      task =
        Task.async(fn ->
          {Authorization.can?(user, slug_b), Authorization.get_role_permissions(c),
           Authorization.load_access(user), Authorization.has_role?(user, b.slug),
           Authorization.get_role_permission_sources(a)}
        end)

      assert {true, permissions, access, true, sources} = Task.await(task, 2_000)
      assert Enum.map(permissions, & &1.slug) == Enum.sort([slug_a, slug_b])
      assert MapSet.equal?(access.role_slugs, MapSet.new([a.slug, b.slug, c.slug]))
      assert [{%Permission{slug: ^slug_b}, [_]}] = sources.inherited
    end
  end

  describe "role permission sources (RBAC-16)" do
    test "direct and inherited, each inherited one with the roles it comes from" do
      [top, left, right, bottom] = for _ <- 1..4, do: create_role()
      [shared, own, both] = for _ <- 1..3, do: create_permission()

      {:ok, _} = Authorization.assign_permission_to_role(top, shared)
      {:ok, _} = Authorization.assign_permission_to_role(left, both)
      {:ok, _} = Authorization.assign_permission_to_role(bottom, both)
      {:ok, _} = Authorization.assign_permission_to_role(bottom, own)
      {:ok, _} = Authorization.assign_parent_role(left, top)
      {:ok, _} = Authorization.assign_parent_role(right, top)
      {:ok, _} = Authorization.assign_parent_role(bottom, left)
      {:ok, _} = Authorization.assign_parent_role(bottom, right)

      assert {%{direct: direct, inherited: inherited}, 1} =
               count_queries(fn -> Authorization.get_role_permission_sources(bottom) end)

      assert Enum.map(direct, & &1.id) |> Enum.sort() == Enum.sort([own.id, both.id])

      assert [{%Permission{id: shared_id}, from}] = inherited
      assert shared_id == shared.id
      assert Enum.map(from, & &1.id) == [top.id]
    end

    test "revoking an inherited permission says where it comes from" do
      {[parent, child], [parent_slug, _]} = chain(2)
      permission = Authorization.get_permission_by_slug(parent_slug)

      assert {:error, :inherited_permission} =
               Authorization.remove_permission_from_role(child, permission)

      assert {:error, :not_found} =
               Authorization.remove_permission_from_role(child, create_permission())

      assert :ok = Authorization.remove_permission_from_role(parent, permission)
    end
  end

  describe "system roles and permissions (RBAC-04)" do
    setup do
      {:ok, _} = Rephi.Seeds.run(admin_email: nil, admin_password: nil, admin: :optional)
      :ok
    end

    test "cannot be deleted; their slug cannot change; the rest can" do
      role = Authorization.get_role_by_slug("manager")
      permission = Authorization.get_permission_by_slug("roles:view")
      assert role.is_system and permission.is_system

      assert Authorization.delete_role(role) == {:error, :system_role}
      assert Authorization.delete_permission(permission) == {:error, :system_permission}

      assert {:error, changeset} = Authorization.update_role(role, %{slug: "boss"})
      assert %{slug: ["cannot be changed on a system role"]} = errors_on(changeset)
      assert {:error, changeset} = Authorization.update_permission(permission, %{slug: "r:v"})
      assert %{slug: ["cannot be changed on a system permission"]} = errors_on(changeset)

      assert {:ok, %Role{name: "Boss", slug: "manager"}} =
               Authorization.update_role(role, %{name: "Boss", slug: "manager"})

      assert {:ok, _} = Authorization.update_permission(permission, %{description: "x"})

      custom = create_role()
      assert {:ok, %Role{slug: "renamed"}} = Authorization.update_role(custom, %{slug: "renamed"})
      assert {:ok, _} = Authorization.delete_role(custom)
      assert {:ok, _} = Authorization.delete_permission(create_permission())
    end

    test "is_system cannot be set from attributes" do
      assert {:ok, %Role{is_system: false} = role} =
               Authorization.create_role(%{name: "x", slug: "x", is_system: true})

      assert {:ok, %Role{is_system: false}} = Authorization.update_role(role, %{is_system: true})

      assert {:ok, %Permission{is_system: false}} =
               Authorization.create_permission(%{name: "x", slug: "x:y", is_system: true})
    end
  end

  describe "the last admin (RBAC-04)" do
    setup do
      admin_role = seed_admin_role()
      admin = user_with_role(admin_role)
      {:ok, admin_role: admin_role, admin: admin}
    end

    test "cannot lose the role", %{admin_role: role, admin: admin} do
      assert Authorization.remove_role_from_user(admin, role) == {:error, :last_admin}
      assert Authorization.has_role?(admin, role)

      other = user_with_role(role)
      assert :ok = Authorization.remove_role_from_user(admin, role)
      assert Authorization.remove_role_from_user(other, role) == {:error, :last_admin}
    end

    test "cannot be deleted", %{admin: admin} do
      assert Accounts.delete_user(admin) == {:error, :last_admin}
      assert Accounts.get_user(admin.id)

      assert {:ok, _} = Accounts.delete_user(create_user())
    end

    test "holding the role through a child role counts, and removing that path is guarded",
         %{admin_role: admin_role, admin: admin} do
      super_role = create_role()
      {:ok, _} = Authorization.assign_parent_role(super_role, admin_role)
      super_user = user_with_role(super_role)

      assert :ok = Authorization.remove_role_from_user(admin, admin_role)
      assert Authorization.has_role?(super_user, admin_role.slug)

      assert Authorization.remove_parent_role(super_role, admin_role) == {:error, :last_admin}
      assert Authorization.delete_role(super_role) == {:error, :last_admin}
      assert Authorization.get_role(super_role.id)
    end

    test "two admins removing each other concurrently leave one", %{admin_role: role, admin: a} do
      b = user_with_role(role)

      results =
        [a, b]
        |> Enum.map(fn user ->
          Task.async(fn -> Authorization.remove_role_from_user(user, role) end)
        end)
        |> Task.await_many()

      assert Enum.sort(results) == [:ok, {:error, :last_admin}]

      assert Repo.aggregate(from(ur in UserRole, where: ur.role_id == ^role.id), :count) == 1
    end

    test "without an admin role nothing is guarded" do
      Repo.delete_all(Role)
      user = create_user()
      role = create_role()
      {:ok, _} = Authorization.assign_role_to_user(user, role)
      assert :ok = Authorization.remove_role_from_user(user, role)
      assert {:ok, _} = Accounts.delete_user(user)
    end
  end

  describe "no escalation (RBAC-05)" do
    setup do
      admin_role = seed_admin_role()
      admin = user_with_role(admin_role)

      {[helper_role], [helper_permission]} = chain(1)
      helpdesk = user_with_role(helper_role)

      {:ok,
       admin: admin,
       admin_role: admin_role,
       helpdesk: helpdesk,
       helper_role: helper_role,
       helper_permission: Authorization.get_permission_by_slug(helper_permission)}
    end

    test "a role can only be granted or revoked by someone holding it, or an admin", ctx do
      target = create_user()
      other_role = create_role()

      assert {:error, :escalation} =
               Authorization.assign_role_to_user(ctx.helpdesk, ctx.admin_role,
                 actor: ctx.helpdesk
               )

      assert {:error, :escalation} =
               Authorization.assign_role_to_user(target, other_role, actor: ctx.helpdesk)

      refute Authorization.has_role?(ctx.helpdesk, ctx.admin_role)

      assert {:ok, %UserRole{assigned_by: assigned_by}} =
               Authorization.assign_role_to_user(target, ctx.helper_role,
                 actor: Authorization.load_access(ctx.helpdesk)
               )

      assert assigned_by == ctx.helpdesk.id

      assert {:ok, _} = Authorization.assign_role_to_user(target, other_role, actor: ctx.admin)

      assert {:error, :escalation} =
               Authorization.remove_role_from_user(target, other_role, actor: ctx.helpdesk)

      assert :ok =
               Authorization.remove_role_from_user(target, ctx.helper_role, actor: ctx.helpdesk)
    end

    test "a permission can only be granted or revoked by someone holding it, or an admin", ctx do
      role = create_role()
      foreign = create_permission()

      assert {:error, :escalation} =
               Authorization.assign_permission_to_role(role, foreign, actor: ctx.helpdesk)

      assert {:error, :escalation} =
               Authorization.assign_permission_to_user(ctx.helpdesk, foreign, actor: ctx.helpdesk)

      assert {:ok, _} =
               Authorization.assign_permission_to_role(role, ctx.helper_permission,
                 actor: ctx.helpdesk
               )

      assert {:ok, _} = Authorization.assign_permission_to_role(role, foreign, actor: ctx.admin)

      assert {:error, :escalation} =
               Authorization.remove_permission_from_role(role, foreign, actor: ctx.helpdesk)

      assert :ok =
               Authorization.remove_permission_from_role(role, ctx.helper_permission,
                 actor: ctx.helpdesk
               )
    end

    test "can_manage_user?/2", ctx do
      plain = create_user()
      peer = user_with_role(ctx.helper_role)

      assert Authorization.can_manage_user?(ctx.helpdesk, plain)
      assert Authorization.can_manage_user?(ctx.helpdesk, peer)
      refute Authorization.can_manage_user?(ctx.helpdesk, ctx.admin)
      assert Authorization.can_manage_user?(ctx.admin, ctx.helpdesk)
      refute Authorization.can_manage_user?(nil, plain)
    end
  end

  describe "removals (RBAC-17)" do
    test "remove a role: :ok once, then :not_found" do
      user = create_user()
      role = create_role()
      {:ok, _} = Authorization.assign_role_to_user(user, role)

      assert :ok = Authorization.remove_role_from_user(user, role)
      assert {:error, :not_found} = Authorization.remove_role_from_user(user, role)
    end

    test "concurrent removals: one :ok, the rest :not_found, no exception" do
      user = create_user()
      role = create_role()
      permission = create_permission()
      {:ok, _} = Authorization.assign_role_to_user(user, role)
      {:ok, _} = Authorization.assign_permission_to_role(role, permission)
      {:ok, _} = Authorization.assign_permission_to_user(user, permission)

      for remove <- [
            fn -> Authorization.remove_role_from_user(user, role) end,
            fn -> Authorization.remove_permission_from_role(role, permission) end,
            fn -> Authorization.remove_permission_from_user(user, permission) end
          ] do
        results = 1..4 |> Enum.map(fn _ -> Task.async(remove) end) |> Task.await_many()
        assert Enum.frequencies(results) == %{:ok => 1, {:error, :not_found} => 3}
      end
    end
  end

  describe "assigned_by (RBAC-14)" do
    test "must be an existing user, and survives as nil when that user is deleted" do
      user = create_user()
      role = create_role()

      for bad <- [999_999_999, 3_000_000_000] do
        assert {:error, changeset} =
                 Authorization.assign_role_to_user(user, role, assigned_by: bad)

        assert %{assigned_by: ["does not exist"]} = errors_on(changeset)
      end

      granter = create_user()

      {:ok, user_role} =
        Authorization.assign_role_to_user(user, role, actor: nil, assigned_by: granter.id)

      assert user_role.assigned_by == granter.id

      {:ok, _} = Accounts.delete_user(granter)
      assert %UserRole{assigned_by: nil} = Repo.get!(UserRole, user_role.id)
    end
  end

  describe "slugs and lengths (RBAC-15)" do
    test "roles" do
      for slug <- ~w(admin content_editor content-editor a1 x) do
        assert {:ok, _} = Authorization.create_role(%{name: "n", slug: slug}), slug
      end

      long = String.duplicate("a", 300)

      for slug <- ["x\n", "-", "_", "a-", "-a", "a__b", "Admin", "a b", "a:b", long, ""] do
        assert {:error, %{errors: errors}} = Authorization.create_role(%{name: "n", slug: slug})
        assert Keyword.has_key?(errors, :slug), inspect(slug)
      end

      assert {:error, changeset} = Authorization.create_role(%{name: long, slug: "ok"})
      assert %{name: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

    test "permissions are category:action" do
      for slug <- ~w(users:view notifications:broadcast a:b:c reports:export_all x-y:z) do
        assert {:ok, _} = Authorization.create_permission(%{name: "n", slug: slug}), slug
      end

      for slug <- ["users", ":::", "users:", ":view", "Users:View", "users:view\n", "a::b", "-:-"] do
        assert {:error, %{errors: errors}} =
                 Authorization.create_permission(%{name: "n", slug: slug})

        assert Keyword.has_key?(errors, :slug), inspect(slug)
      end

      assert {:error, _} =
               Authorization.create_permission(%{
                 name: "n",
                 slug: "a:" <> String.duplicate("b", 300)
               })
    end
  end

  describe "permission parent (RBAC-09)" do
    test "is grouping only, cannot be the permission itself, and survives deleting the parent" do
      parent = create_permission()
      child = create_permission(%{parent_id: parent.id})
      user = create_user()
      {:ok, _} = Authorization.assign_permission_to_user(user, parent)

      refute Authorization.can?(user, child.slug)

      assert {:error, changeset} =
               Authorization.update_permission(parent, %{parent_id: parent.id})

      assert %{parent_id: ["cannot be the permission itself"]} = errors_on(changeset)

      assert {:ok, _} = Authorization.delete_permission(parent)
      assert %Permission{parent_id: nil} = Authorization.get_permission(child.id)
    end
  end

  test "timestamps are UTC datetimes on every schema (RBAC-21)" do
    role = create_role()
    permission = create_permission()
    user = create_user()
    {:ok, user_role} = Authorization.assign_role_to_user(user, role)
    {:ok, role_permission} = Authorization.assign_permission_to_role(role, permission)

    for record <- [role, permission, user, user_role, role_permission] do
      assert %DateTime{time_zone: "Etc/UTC"} = record.inserted_at
    end
  end

  describe "hierarchy links (assign_parent_role/3, remove_parent_role/3)" do
    test "keep who linked them and the notes; seeded-style system links cannot be removed" do
      [child, parent] = for _ <- 1..2, do: create_role()
      linker = create_user()

      assert {:ok, %RoleRole{} = link} =
               Authorization.assign_parent_role(child, parent,
                 assigned_by: linker.id,
                 notes: "Editors do what authors do"
               )

      assert link.assigned_by == linker.id
      assert link.notes == "Editors do what authors do"
      refute link.is_system

      assert {:error, changeset} =
               Authorization.assign_parent_role(create_role(), parent,
                 notes: String.duplicate("x", 2001)
               )

      assert %{notes: [_]} = errors_on(changeset)

      Repo.update_all(RoleRole, set: [is_system: true])
      assert Authorization.remove_parent_role(child, parent) == {:error, :system_link}
      assert [{_, %RoleRole{is_system: true}}] = Authorization.list_parent_roles(child)

      Repo.update_all(RoleRole, set: [is_system: false])
      assert Authorization.remove_parent_role(child, parent) == :ok
      assert Authorization.remove_parent_role(child, parent) == {:error, :not_found}
    end

    test "a cycle is flagged as such in the changeset" do
      [a, b] = for _ <- 1..2, do: create_role()
      {:ok, _} = Authorization.assign_parent_role(b, a)

      for {child, parent} <- [{a, a}, {a, b}] do
        assert {:error, %Ecto.Changeset{errors: [parent_role_id: {_message, opts}]}} =
                 Authorization.assign_parent_role(child, parent)

        assert opts[:validation] == :cycle
      end
    end

    test "with :actor, a non-admin must hold both roles; an admin may link anything" do
      admin_role = seed_admin_role()
      [child, parent, other] = for _ <- 1..3, do: create_role()

      holder = create_user()
      for role <- [child, parent], do: {:ok, _} = Authorization.assign_role_to_user(holder, role)
      access = Authorization.load_access(holder)

      assert Authorization.can_link_roles?(access, child, parent)
      refute Authorization.can_link_roles?(access, child, other)
      refute Authorization.can_link_roles?(access, other, parent)
      refute Authorization.can_link_roles?(nil, child, parent)
      refute Authorization.can_link_roles?(access, child, nil)

      assert {:error, :escalation} = Authorization.assign_parent_role(child, other, actor: access)

      assert {:error, :escalation} =
               Authorization.assign_parent_role(other, parent, actor: access)

      assert {:ok, link} = Authorization.assign_parent_role(child, parent, actor: access)
      assert link.assigned_by == holder.id

      outsider = Authorization.load_access(create_user())

      assert Authorization.remove_parent_role(child, parent, actor: outsider) ==
               {:error, :escalation}

      assert Authorization.remove_parent_role(child, parent, actor: access) == :ok

      admin = Authorization.load_access(user_with_role(admin_role))
      assert {:ok, _} = Authorization.assign_parent_role(other, parent, actor: admin)
      assert Authorization.remove_parent_role(other, parent, actor: admin) == :ok
    end

    test "list_parent_roles/1 and list_child_roles/1: direct links only, by slug, one query" do
      root = create_role(%{slug: "zz_root"})
      [a, b] = [create_role(%{slug: "aa_mid"}), create_role(%{slug: "bb_mid"})]
      leaf = create_role()

      for mid <- [b, a], do: {:ok, _} = Authorization.assign_parent_role(mid, root)
      for mid <- [a, b], do: {:ok, _} = Authorization.assign_parent_role(leaf, mid)

      assert {parents, 1} = count_queries(fn -> Authorization.list_parent_roles(leaf) end)
      assert Enum.map(parents, fn {role, _link} -> role.slug end) == ["aa_mid", "bb_mid"]

      assert {children, 1} = count_queries(fn -> Authorization.list_child_roles(root) end)
      assert Enum.map(children, fn {role, _link} -> role.slug end) == ["aa_mid", "bb_mid"]
      assert Authorization.list_child_roles(leaf) == []
      assert Authorization.list_parent_roles(root) == []

      assert Authorization.list_parent_roles(%Role{}) == []
      assert Authorization.list_child_roles(nil) == []
    end
  end

  describe "user permissions (get_user_permission_sources/1, remove_permission_from_user/3)" do
    test "direct grants with their data, and every effective permission with its sources" do
      {[root, mid], [root_slug, mid_slug]} = chain(2)
      shared = create_permission(%{slug: "aa:shared"})
      {:ok, _} = Authorization.assign_permission_to_role(root, shared)
      {:ok, _} = Authorization.assign_permission_to_role(mid, shared)
      direct_only = create_permission(%{slug: "zz:direct"})

      granter = create_user()
      user = user_with_role(mid)

      {:ok, _} =
        Authorization.assign_permission_to_user(user, direct_only,
          assigned_by: granter.id,
          notes: "Audit"
        )

      {:ok, _} = Authorization.assign_permission_to_user(user, shared)

      assert {%{direct: direct, effective: effective}, 2} =
               count_queries(fn -> Authorization.get_user_permission_sources(user) end)

      assert [%{permission: %Permission{slug: "aa:shared"}}, granted] = direct
      assert granted.permission.slug == "zz:direct"
      assert granted.assigned_by == granter.id
      assert granted.notes == "Audit"

      by_slug = Map.new(effective, &{&1.permission.slug, &1})
      assert Enum.map(effective, & &1.permission.slug) == Enum.sort(Map.keys(by_slug))
      assert MapSet.new(Map.keys(by_slug)) == Authorization.load_access(user).permission_slugs

      assert %{direct: true, roles: roles} = by_slug["aa:shared"]
      assert Enum.map(roles, & &1.slug) == Enum.sort([root.slug, mid.slug])
      assert %{direct: false, roles: [%{id: root_id}]} = by_slug[root_slug]
      assert root_id == root.id
      assert %{direct: false, roles: [%{slug: mid_role_slug}]} = by_slug[mid_slug]
      assert mid_role_slug == mid.slug
      assert %{direct: true, roles: []} = by_slug["zz:direct"]

      assert Authorization.get_user_permission_sources(%User{}) == %{direct: [], effective: []}
      assert Authorization.get_user_permission_sources(nil) == %{direct: [], effective: []}
    end

    test "revoking what the user only holds through a role is refused as such" do
      {[role], [slug]} = chain(1)
      user = user_with_role(role)
      permission = Authorization.get_permission_by_slug(slug)

      assert Authorization.remove_permission_from_user(user, permission) ==
               {:error, :granted_through_role}

      assert Authorization.remove_permission_from_user(user, create_permission()) ==
               {:error, :not_found}

      {:ok, _} = Authorization.assign_permission_to_user(user, permission)
      assert Authorization.remove_permission_from_user(user, permission) == :ok
      assert Authorization.can?(user, permission)
    end
  end
end
