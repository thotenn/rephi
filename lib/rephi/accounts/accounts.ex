defmodule Rephi.Accounts do
  @moduledoc """
  The Accounts context for managing users.

  This module provides functions for user management including
  creation, retrieval, authentication, and listing users.
  """

  import Ecto.Query, warn: false
  alias Rephi.Repo
  alias Rephi.Accounts.User

  def get_user(id) do
    User
    |> Repo.get(id)
    |> Repo.preload([:roles, :permissions])
  end

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
