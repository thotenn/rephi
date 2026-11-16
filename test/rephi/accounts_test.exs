defmodule Rephi.AccountsTest do
  use Rephi.DataCase, async: true

  import Rephi.AuthTestHelpers

  alias Rephi.Accounts
  alias Rephi.Accounts.User

  describe "emails (SEC-13, RBAC-13)" do
    test "are stored trimmed and lowercased" do
      {:ok, user} =
        Accounts.create_user(%{email: "  Jane.Doe@Example.COM ", password: "password123"})

      assert user.email == "jane.doe@example.com"
    end

    test "are unique regardless of case" do
      {:ok, _} = Accounts.create_user(%{email: "a@example.com", password: "password123"})

      assert {:error, changeset} =
               Accounts.create_user(%{email: "A@Example.com", password: "password123"})

      assert errors_on(changeset) == %{email: ["has already been taken"]}
    end

    test "with a trailing newline or inner whitespace are rejected" do
      for email <- ["nl@example.com\nx", "a b@example.com", "a@b@example.com", "a@example.com,b"] do
        assert {:error, changeset} =
                 Accounts.create_user(%{email: email, password: "password123"})

        assert %{email: [_]} = errors_on(changeset), "accepted #{inspect(email)}"
      end
    end

    test "are looked up ignoring case and surrounding whitespace" do
      user = create_user(%{email: "case@example.com"})

      assert Accounts.get_user_by_email(" CASE@Example.com ").id == user.id
      assert {:ok, %User{}} = Accounts.authenticate_user("Case@Example.com", "password123")
    end

    test "get_user_by_email/1 with something that is not a string is nil" do
      assert Accounts.get_user_by_email(nil) == nil
      assert Accounts.get_user_by_email(%{"a" => 1}) == nil
    end

    test "the database rejects a duplicate in another case even without the changeset" do
      create_user(%{email: "raw@example.com"})
      now = DateTime.utc_now(:second)

      assert_raise Postgrex.Error, ~r/users_email_index/, fn ->
        Repo.insert_all("users", [
          %{email: "RAW@example.com", hashed_password: "x", inserted_at: now, updated_at: now}
        ])
      end
    end

    test "email and hashed_password are NOT NULL in the database" do
      now = DateTime.utc_now(:second)

      assert_raise Postgrex.Error, ~r/not_null_violation|null value/, fn ->
        Repo.insert_all("users", [
          %{email: nil, hashed_password: "x", inserted_at: now, updated_at: now}
        ])
      end

      assert_raise Postgrex.Error, ~r/not_null_violation|null value/, fn ->
        Repo.insert_all("users", [
          %{email: "nohash@example.com", hashed_password: nil, inserted_at: now, updated_at: now}
        ])
      end
    end
  end

  describe "passwords (SEC-18, SEC-19)" do
    test "need at least 8 characters" do
      assert {:error, changeset} =
               Accounts.create_user(%{email: "p7@example.com", password: "1234567"})

      assert errors_on(changeset) == %{password: ["should be at least 8 character(s)"]}

      assert {:ok, _} = Accounts.create_user(%{email: "p8@example.com", password: "12345678"})
    end

    test "are limited to 72 bytes, not characters (bcrypt ignores the rest)" do
      # 75 bytes: past bcrypt's 72-byte limit
      password = String.duplicate("€", 25)
      assert String.length(password) == 25

      assert {:error, changeset} =
               Accounts.create_user(%{email: "mb@example.com", password: password})

      assert errors_on(changeset) == %{password: ["should be at most 72 byte(s)"]}

      assert {:ok, _} =
               Accounts.create_user(%{
                 email: "mb@example.com",
                 password: String.duplicate("€", 24)
               })
    end

    test "never show up when a user or a changeset is inspected" do
      changeset =
        User.registration_changeset(%User{}, %{
          email: "redact@example.com",
          password: "a-secret-password",
          password_confirmation: "a-secret-password"
        })

      {:ok, user} = Repo.insert(changeset)

      refute inspect(user) =~ user.hashed_password
      refute inspect(changeset) =~ "a-secret-password"
      refute inspect(changeset) =~ changeset.changes.hashed_password
      assert user.password_confirmation == nil
    end
  end

  describe "authenticate_user/2 (SEC-10, SEC-11)" do
    test "the same error for an unknown email and for a wrong password" do
      create_user(%{email: "known@example.com"})

      assert Accounts.authenticate_user("known@example.com", "wrong-password") ==
               {:error, :invalid_credentials}

      assert Accounts.authenticate_user("unknown@example.com", "wrong-password") ==
               {:error, :invalid_credentials}
    end

    test "arguments that are not strings are invalid credentials, not an exception" do
      create_user(%{email: "known@example.com"})

      for {email, password} <- [{nil, "x"}, {"known@example.com", 123}, {%{}, []}, {nil, nil}] do
        assert Accounts.authenticate_user(email, password) == {:error, :invalid_credentials}
      end
    end
  end

  describe "token revocation (SEC-08, SEC-09)" do
    setup do
      user = create_user()
      Phoenix.PubSub.subscribe(Rephi.PubSub, Accounts.socket_id(user))
      {:ok, user: user}
    end

    test "a password change bumps token_version and disconnects the user's sockets",
         %{user: user} do
      {:ok, updated} =
        Accounts.change_password(user, "password123", %{password: "another-password"})

      assert updated.token_version == user.token_version + 1
      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: "user_socket:" <> _}
    end

    test "revoke_tokens/1 bumps token_version and disconnects the user's sockets", %{user: user} do
      assert {:ok, %User{token_version: 1}} = Accounts.revoke_tokens(user)
      assert {:ok, %User{token_version: 2}} = Accounts.revoke_tokens(user)
      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect"}
    end

    test "deleting the user disconnects its sockets", %{user: user} do
      {:ok, _} = Accounts.delete_user(user)
      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect"}
    end

    test "a password change that fails validation neither bumps nor disconnects",
         %{user: user} do
      assert {:error, _} = Accounts.change_password(user, "password123", %{password: "short"})
      assert {:error, _} = Accounts.change_password(user, "wrong", %{password: "long-enough"})
      assert Accounts.get_user(user.id).token_version == 0
      refute_receive %Phoenix.Socket.Broadcast{event: "disconnect"}
    end

    test "creating a user starts at token_version 0", %{user: user} do
      assert user.token_version == 0
    end
  end

  describe "reset_password/1" do
    setup do
      {:ok, user: create_user()}
    end

    test "sets a random temporary password, flags the account and ends its sessions",
         %{user: user} do
      Phoenix.PubSub.subscribe(Rephi.PubSub, Accounts.socket_id(user))

      assert {:ok, %User{} = updated, password} = Accounts.reset_password(user)

      assert String.length(password) == 24
      assert password =~ ~r/\A[A-Za-z0-9_-]+\z/
      assert updated.must_change_password
      assert updated.token_version == user.token_version + 1
      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect"}

      stored = Accounts.get_user(user.id)
      assert stored.must_change_password
      refute stored.hashed_password == user.hashed_password
      refute stored.hashed_password =~ password
      assert {:ok, _} = Accounts.authenticate_user(user.email, password)

      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user(user.email, "password123")

      assert {:ok, _, another} = Accounts.reset_password(stored)
      refute another == password
    end

    test "changing the password afterwards clears the flag", %{user: user} do
      {:ok, user, password} = Accounts.reset_password(user)

      assert {:ok, %User{must_change_password: false} = changed} =
               Accounts.change_password(user, password, %{password: "my-own-passphrase"})

      assert changed.token_version == user.token_version + 1
      refute Accounts.get_user(user.id).must_change_password
    end

    test "a user deleted in the meantime is not found", %{user: user} do
      {:ok, _} = Accounts.delete_user(user)
      assert Accounts.reset_password(user) == {:error, :not_found}
    end
  end

  test "count_users/0 counts every account" do
    before = Accounts.count_users()
    create_user()
    assert Accounts.count_users() == before + 1
  end
end
