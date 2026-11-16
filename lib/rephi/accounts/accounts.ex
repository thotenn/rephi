defmodule Rephi.Accounts do
  @moduledoc """
  The Accounts context for managing users.

  This module provides functions for user management including
  creation, retrieval, authentication, and listing users.
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

  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def authenticate_user(email, password) do
    user = get_user_by_email(email)

    if user && User.verify_password(password, user.hashed_password) do
      {:ok, user}
    else
      {:error, :invalid_credentials}
    end
  end

  @doc """
  Returns a list of all users with their roles and permissions preloaded.

  ## Examples

      iex> list_users()
      [%User{email: "admin@admin.com", ...}, ...]

  """
  def list_users do
    User
    |> Repo.all()
    |> Repo.preload([:roles, :permissions])
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end
end
