defmodule Rephi.Accounts.User do
  @moduledoc """
  A user account. `email` is stored trimmed and lowercased; incrementing
  `token_version` revokes every token issued before. Password fields are redacted.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Rephi.Authorization.{Permission, Role, UserPermission, UserRole}

  # bcrypt only looks at the first 72 bytes of a password.
  @max_password_bytes 72
  @min_password_length 8

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :password_confirmation, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :token_version, :integer, default: 0
    field :must_change_password, :boolean, default: false

    # Assigned only; effective rights are `Rephi.Authorization.load_access/1`.
    many_to_many :roles, Role, join_through: UserRole, preload_order: [asc: :slug]

    many_to_many :permissions, Permission,
      join_through: UserPermission,
      preload_order: [asc: :slug]

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset to register a user: email and password, both required.
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :password_confirmation])
    |> validate_required([:email, :password])
    |> validate_email()
    |> validate_password()
  end

  @doc """
  Changeset to change the email of a user. Nothing else can be changed with
  it: a `password` in `attrs` is ignored.
  """
  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_required([:email])
    |> validate_email()
  end

  @doc """
  Changeset to set a new password; increments `token_version`, revoking older tokens.
  """
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password, :password_confirmation])
    |> validate_required([:password])
    |> validate_password()
  end

  defp validate_email(changeset) do
    changeset
    |> update_change(:email, &normalize_email/1)
    |> validate_format(:email, ~r/\A[^@,;\s]+@[^@,;\s]+\z/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
    |> unique_constraint(:email)
  end

  defp validate_password(changeset) do
    changeset
    |> validate_length(:password, min: @min_password_length)
    |> validate_length(:password, max: @max_password_bytes, count: :bytes)
    |> validate_confirmation(:password, message: "passwords do not match")
    |> hash_password()
  end

  @doc """
  Trims and lowercases an email: the form it is stored and looked up in.
  """
  @spec normalize_email(String.t()) :: String.t()
  def normalize_email(email) when is_binary(email) do
    email |> String.trim() |> String.downcase()
  end

  defp hash_password(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        changeset
        |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
        |> delete_change(:password)
        |> delete_change(:password_confirmation)
        |> revoke_tokens_if_persisted()

      _ ->
        changeset
    end
  end

  defp revoke_tokens_if_persisted(%Ecto.Changeset{data: %__MODULE__{} = user} = changeset) do
    case Ecto.get_meta(user, :state) do
      :loaded -> put_change(changeset, :token_version, user.token_version + 1)
      _ -> changeset
    end
  end

  @doc """
  Checks a password against a bcrypt hash.
  """
  def verify_password(password, hashed_password) do
    Bcrypt.verify_pass(password, hashed_password)
  end
end
