defmodule Rephi.Accounts do
  import Ecto.Query, warn: false
  alias Rephi.Repo
  alias Rephi.Accounts.User

  def get_user!(id), do: Repo.get!(User, id)

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
end
