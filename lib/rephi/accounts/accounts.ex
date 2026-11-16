defmodule Rephi.Accounts do
  @moduledoc """
  The Accounts context for managing users.

  This module provides functions for user management including
  creation, retrieval, authentication, and listing users.

  ## Token revocation

  Every JWT carries the `token_version` of its user (see
  `RephiWeb.Auth.Guardian`). Three things end the sessions of a user: a
  password change (`update_user/2`), an explicit logout (`revoke_tokens/1`)
  and deleting the account (`delete_user/1`). Each of them also closes the
  WebSocket connections the user has open, by broadcasting `"disconnect"` on
  `socket_id/1`.
  """

  import Ecto.Query, warn: false
  alias Rephi.Repo
  alias Rephi.Accounts.User

  @doc """
  Gets a user by id with roles and permissions preloaded.

  Returns `nil` when the user does not exist or `id` is not a valid id; it
  never raises on malformed input.
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
  def fetch_user(id) do
    with {:ok, user} <- Repo.fetch(User, id) do
      {:ok, Repo.preload(user, [:roles, :permissions])}
    end
  end

  @doc """
  Gets a user by id, raising `Ecto.NoResultsError` if it does not exist.
  """
  def get_user!(id) do
    User
    |> Repo.get!(id)
    |> Repo.preload([:roles, :permissions])
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

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
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
  Returns a list of all users with their roles and permissions preloaded.

  ## Examples

      iex> list_users()
      [%User{email: "user@example.com", ...}, ...]

  """
  def list_users do
    User
    |> Repo.all()
    |> Repo.preload([:roles, :permissions])
  end

  @doc """
  Updates a user.

  Changing the password revokes the tokens of the user and closes its open
  WebSocket connections.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    with {:ok, updated} <- user |> User.changeset(attrs) |> Repo.update() do
      if updated.token_version != user.token_version, do: disconnect_sockets(updated)
      {:ok, updated}
    end
  end

  @doc """
  Deletes a user.

  Its tokens stop working (there is no user to load any more) and its open
  WebSocket connections are closed.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    with {:ok, deleted} <- Repo.delete(user) do
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
