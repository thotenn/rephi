defmodule Rephi.Accounts do
  @moduledoc """
  The Accounts context for managing users.

  This module provides functions for user management including
  creation, retrieval, authentication, and listing users.

  Password changes and resets, logout (`revoke_tokens/1`) and deletion revoke
  the user's tokens (`token_version`) and close its WebSocket connections.
  """

  import Ecto.Query, warn: false
  alias Rephi.{Authorization, Pagination, Repo}
  alias Rephi.Accounts.User

  @doc """
  Gets a user by id, or `nil` (also for an id that cannot be a primary key).
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
  Loads `user.roles` and the directly granted `user.permissions`, ordered by slug.
  """
  def preload_grants(user_or_users) do
    Repo.preload(user_or_users, [:roles, :permissions], force: true)
  end

  @doc """
  Gets a user by email (ignoring case and surrounding whitespace), or `nil`.
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

  The role is `config :rephi, Rephi.Accounts, default_role: "user"` (`nil` for none).
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
  Checks an email and password: `{:ok, user}` or `{:error, :invalid_credentials}`.

  An unknown email still spends a password check's time, so response times do
  not reveal which emails are registered.
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

  @doc "Number of user accounts."
  @spec count_users() :: non_neg_integer()
  def count_users, do: Repo.aggregate(User, :count)

  @doc """
  Changes the email of a user. Only the email: anything else in `attrs`
  (a `password`, for instance) is ignored. See `change_password/3`.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.email_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Sets a new password for a user who proves the current one, revoking every
  earlier token and closing its sockets. The returned user carries the new
  `token_version`.
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
  Sets a random temporary password (returned, never stored in clear), flags
  `must_change_password` and ends every session of the user.
  """
  @spec reset_password(User.t()) :: {:ok, User.t(), String.t()} | {:error, :not_found}
  def reset_password(%User{id: id} = user) do
    password = temporary_password()

    result =
      Repo.transact(fn ->
        changeset =
          user
          |> User.password_changeset(%{password: password})
          # Incremented in SQL: a concurrent logout must not leave a token alive.
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

    # After the commit, or a client re-checking its token on disconnect still finds it valid.
    with {:ok, updated} <- result do
      disconnect_sockets(updated)
      {:ok, updated, password}
    end
  end

  defp temporary_password do
    18 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end

  @doc """
  Deletes a user.

  Also closes its sockets. Returns `{:error, :last_admin}`, deleting nothing,
  for the last user holding the admin role.

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
  Revokes every token issued to the user so far and closes its sockets (logout).
  Returns `{:ok, user}` with the new `token_version`, or `{:error, :not_found}`.
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

  # Via PubSub so the context does not depend on the web layer.
  defp disconnect_sockets(%User{} = user) do
    topic = socket_id(user)

    Phoenix.PubSub.broadcast(Rephi.PubSub, topic, %Phoenix.Socket.Broadcast{
      topic: topic,
      event: "disconnect",
      payload: %{}
    })
  end
end
