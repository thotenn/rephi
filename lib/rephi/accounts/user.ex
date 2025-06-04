defmodule Rephi.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias Bcrypt
  alias Rephi.Authorization.{Role, Permission}
  alias Rephi.Accounts.{UserRole, UserPermission}

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true
    field :hashed_password, :string

    many_to_many :roles, Role, join_through: UserRole
    many_to_many :permissions, Permission, join_through: UserPermission

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :password_confirmation])
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unique_constraint(:email)
    |> validate_length(:password, min: 6, max: 72)
    |> validate_confirmation(:password, message: "passwords do not match")
    |> hash_password()
  end

  defp hash_password(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        put_change(changeset, :hashed_password, Bcrypt.hash_pwd_salt(password))
        |> delete_change(:password)

      _ ->
        changeset
    end
  end

  def verify_password(password, hashed_password) do
    Bcrypt.verify_pass(password, hashed_password)
  end
end
