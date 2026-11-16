defmodule Rephi.Accounts do
  @moduledoc """
  The Accounts context for managing users.

  This module provides functions for user management including
  creation, retrieval, authentication, and listing users.

  ## Token revocation

  Every JWT carries the `token_version` of its user (see
  `RephiWeb.Auth.Guardian`). Four things end the sessions of a user: a
  password change (`change_password/3`), a password reset by an
  administrator (`reset_password/1`), an explicit logout (`revoke_tokens/1`)
  and deleting the account (`delete_user/1`). Each of them also closes the
  WebSocket connections the user has open, by broadcasting `"disconnect"` on
  `socket_id/1`.
  """

  import Ecto.Query, warn: false
  alias Rephi.{Authorization, Pagination, Repo}
  alias Rephi.Accounts.User

  @doc """
  Gets a user by id, or `nil`.

  Never raises: an id that cannot be a primary key (`"abc"`, out of range) is
  not found. Associations are not loaded; see `preload_grants/1`.
  """
  def get_user(id) do
    case fetch_user(id) do
      {:ok, user} -> user
      {:error, :not_found} -> nil
    end
  end

  @doc """
  Like `get_user/1`, but returns `{:ok, user}` or `{:error, :not_found}` so it
  can be chained in a `with` and handled by `RephiWeb.FallbackController`.
  """
  def fetch_user(id), do: Repo.fetch(User, id)

  @doc """
  Loads the roles assigned to the user and the permissions granted to it
  directly (`user.roles`, `user.permissions`), ordered by slug. What the user
  is allowed to do overall is `Rephi.Authorization.load_access/1`.
  """
  def preload_grants(user_or_users) do
    Repo.preload(user_or_users, [:roles, :permissions], force: true)
  end

  @doc """
  Gets a user by email, or `nil`.

  The lookup ignores case and surrounding whitespace, like the changeset does
  when the email is stored. Anything that is not a string is `nil`.
  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: User.normalize_email(email))
  end

  def get_user_by_email(_email), do: nil

  @doc """
  Creates a user from an email and a password. Assigns no role: that is
  `register_user/1`.
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Signs a user up: creates it and assigns it the default role, in one
  transaction (if the role cannot be assigned, no user is created).

  The default role is `config :rephi, Rephi.Accounts, default_role: "user"`
  (the default). `nil` assigns none; a slug with no role behind it is
  skipped.
  """
  def register_user(attrs) do
    Repo.transact(fn ->
      with {:ok, user} <- create_user(attrs),
           :ok <- assign_default_role(user) do
        {:ok, user}
      end
    end)
  end

  @doc """
  The slug of the role new users get (`register_user/1`), or `nil`.
  """
  def default_role_slug do
    :rephi |> Application.get_env(__MODULE__, []) |> Keyword.get(:default_role, "user")
  end

  defp assign_default_role(user) do
    case Authorization.get_role_by_slug(default_role_slug()) do
      nil ->
        :ok

      role ->
        with {:ok, _user_role} <- Authorization.assign_role_to_user(user, role), do: :ok
    end
  end

  @doc """
  Checks an email and password pair.

  Returns `{:ok, user}` or `{:error, :invalid_credentials}`. Both failures
  (unknown email, wrong password) are indistinguishable from outside: the
  unknown email path still spends the time of a password check
  (`Bcrypt.no_user_verify/0`), so response times do not reveal which emails
  are registered. Arguments that are not strings are invalid credentials.
  """
  def authenticate_user(email, password) when is_binary(email) and is_binary(password) do
    case get_user_by_email(email) do
      %User{} = user ->
        if User.verify_password(password, user.hashed_password) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end

      nil ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}
    end
  end

  def authenticate_user(_email, _password), do: {:error, :invalid_credentials}

  @doc """
  Returns one page of users, ordered by id, with their assigned roles and
  direct permissions loaded. See `Rephi.Pagination`.
  """
  def paginate_users(params \\ %{}) do
    from(u in User, order_by: [asc: u.id], preload: [:roles, :permissions])
    |> Pagination.paginate(params)
  end

  @doc """
  Changes the email of a user. Only the email: anything else in `attrs`
  (a `password`, for instance) is ignored. See `change_password/3`.

      iex> update_user(user, %{email: "new@example.com"})
      {:ok, %User{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.email_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Sets a new password for a user who proves the current one.

  `attrs` holds `password` (and optionally `password_confirmation`). On
  success every token issued before is revoked and the user's WebSocket
  connections are closed; the returned user carries the new
  `token_version`, to sign a fresh token with.

  It also clears `must_change_password` (set by `reset_password/1`).

  Returns `{:ok, user}` or `{:error, changeset}` (a wrong current password is
  an error on `:current_password`).
  """
  def change_password(%User{} = user, current_password, attrs) do
    if is_binary(current_password) and
         User.verify_password(current_password, user.hashed_password) do
      with {:ok, updated} <-
             user
             |> User.password_changeset(attrs)
             |> Ecto.Changeset.put_change(:must_change_password, false)
             |> Repo.update() do
        disconnect_sockets(updated)
        {:ok, updated}
      end
    else
      {:error,
       user
       |> Ecto.Changeset.change()
       |> Ecto.Changeset.add_error(:current_password, "is not valid")}
    end
  end

  @doc """
  Replaces the password of a user with a random temporary one, for an
  administrator to hand over (`POST /api/users/:id/password`).

  The temporary password is returned once and only its hash is stored. The
  account is marked `must_change_password`: until the user sets a password
  of its own with `change_password/3`, the API only lets it read `/api/me`,
  change the password and log out (`RephiWeb.Auth.PasswordChangeGate`).
  Every token of the user is revoked and its WebSocket connections are
  closed, as with a password change.

  Who may reset whose password is the caller's business (the controller
  checks the permission and `Rephi.Authorization.can_manage_user?/2`).

  Returns `{:ok, user, temporary_password}` or `{:error, :not_found}` if the
  user no longer exists.

      iex> reset_password(user)
      {:ok, %User{must_change_password: true}, "kJ3r..."}

  """
  @spec reset_password(User.t()) :: {:ok, User.t(), String.t()} | {:error, :not_found}
  def reset_password(%User{id: id} = user) do
    password = temporary_password()

    result =
      Repo.transact(fn ->
        changeset =
          user
          |> User.password_changeset(%{password: password})
          # The version is incremented in the database, so a concurrent
          # logout cannot leave a token alive.
          |> Ecto.Changeset.delete_change(:token_version)
          |> Ecto.Changeset.put_change(:must_change_password, true)

        with {:ok, _user} <- Repo.update(changeset, stale_error_field: :id),
             {1, [updated]} <-
               Repo.update_all(from(u in User, where: u.id == ^id, select: u),
                 inc: [token_version: 1]
               ) do
          {:ok, updated}
        else
          _deleted -> {:error, :not_found}
        end
      end)

    # After the commit: a client that reacts to the disconnect by checking
    # its token must find it revoked.
    with {:ok, updated} <- result do
      disconnect_sockets(updated)
      {:ok, updated, password}
    end
  end

  # 24 URL-safe characters (144 random bits): well within the password rules
  # (8 characters, 72 bytes), and easy to copy.
  defp temporary_password do
    18 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end

  @doc """
  Deletes a user.

  Its tokens stop working (there is no user to load any more) and its open
  WebSocket connections are closed. Returns `{:error, :last_admin}`, and
  deletes nothing, if it is the last user holding the admin role (see
  `Rephi.Authorization.preserving_admins/1`).

      iex> delete_user(user)
      {:ok, %User{}}

  """
  def delete_user(%User{} = user) do
    with {:ok, deleted} <- Authorization.preserving_admins(fn -> Repo.delete(user) end) do
      disconnect_sockets(deleted)
      {:ok, deleted}
    end
  end

  @doc """
  Revokes every token issued to the user so far, on every device, and closes
  its open WebSocket connections. This is what logging out does.

  Returns `{:ok, user}` with the new `token_version`, or
  `{:error, :not_found}` if the user no longer exists. Tokens issued after
  the call are valid.

  ## Examples

      iex> revoke_tokens(user)
      {:ok, %User{token_version: 1}}

  """
  def revoke_tokens(%User{id: id}) do
    query = from u in User, where: u.id == ^id, select: u

    case Repo.update_all(query, inc: [token_version: 1]) do
      {1, [user]} ->
        disconnect_sockets(user)
        {:ok, user}

      {0, []} ->
        {:error, :not_found}
    end
  end

  @doc """
  The id shared by every WebSocket connection of a user (what
  `RephiWeb.UserSocket.id/1` returns). Broadcasting `"disconnect"` on it
  closes them all.
  """
  @spec socket_id(%User{} | integer()) :: String.t()
  def socket_id(%User{id: id}), do: socket_id(id)
  def socket_id(user_id) when is_integer(user_id), do: "user_socket:#{user_id}"

  # Sent through PubSub directly so the context does not depend on the web
  # layer; it is the same message `RephiWeb.Endpoint.broadcast/3` would send.
  defp disconnect_sockets(%User{} = user) do
    topic = socket_id(user)

    Phoenix.PubSub.broadcast(Rephi.PubSub, topic, %Phoenix.Socket.Broadcast{
      topic: topic,
      event: "disconnect",
      payload: %{}
    })
  end
end
