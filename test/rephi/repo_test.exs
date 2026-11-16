defmodule Rephi.RepoTest do
  use Rephi.DataCase, async: true

  import Rephi.AuthTestHelpers

  alias Rephi.Accounts
  alias Rephi.Accounts.User
  alias Rephi.Authorization

  describe "fetch/2" do
    test "returns the record for an integer or a numeric string id" do
      user = create_user()

      assert {:ok, %User{id: id}} = Repo.fetch(User, user.id)
      assert id == user.id
      assert {:ok, %User{id: ^id}} = Repo.fetch(User, Integer.to_string(user.id))
    end

    test "returns :not_found for an id nobody has" do
      assert Repo.fetch(User, 999_999_999) == {:error, :not_found}
    end

    test "returns :not_found, without raising, for values that are not ids" do
      for id <- invalid_ids() ++ [nil, "", " 1", "1 ", 1.5, %{}, [], :atom] do
        assert Repo.fetch(User, id) == {:error, :not_found},
               "expected #{inspect(id)} to be missing"
      end
    end
  end

  describe "cast_id/1" do
    test "accepts positive integers that fit in a bigint" do
      assert Repo.cast_id(1) == {:ok, 1}
      assert Repo.cast_id("42") == {:ok, 42}
      assert Repo.cast_id("9223372036854775807") == {:ok, 9_223_372_036_854_775_807}
    end

    test "rejects everything else" do
      for id <- ["9223372036854775808", "0", "-1", "abc", "1e3", nil] do
        assert Repo.cast_id(id) == :error
      end
    end
  end

  describe "non-raising context getters" do
    test "Accounts.get_user/1 and fetch_user/1" do
      user = create_user()

      assert %User{roles: [], permissions: []} = Accounts.get_user(user.id)
      assert {:ok, %User{roles: [], permissions: []}} = Accounts.fetch_user("#{user.id}")

      for id <- invalid_ids() do
        assert Accounts.get_user(id) == nil
        assert Accounts.fetch_user(id) == {:error, :not_found}
      end
    end

    test "Authorization.get_role/1 and fetch_role/1" do
      role = create_role()

      assert Authorization.get_role(role.id).id == role.id
      assert {:ok, _role} = Authorization.fetch_role("#{role.id}")

      for id <- invalid_ids() do
        assert Authorization.get_role(id) == nil
        assert Authorization.fetch_role(id) == {:error, :not_found}
      end
    end

    test "Authorization.get_permission/1 and fetch_permission/1" do
      permission = create_permission()

      assert Authorization.get_permission(permission.id).id == permission.id
      assert {:ok, _permission} = Authorization.fetch_permission("#{permission.id}")

      for id <- invalid_ids() do
        assert Authorization.get_permission(id) == nil
        assert Authorization.fetch_permission(id) == {:error, :not_found}
      end
    end
  end
end
