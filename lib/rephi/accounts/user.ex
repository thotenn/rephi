defmodule Rephi.Accounts.User do
  @moduledoc """
  A user account.

  ## Fields

    * `email` - stored trimmed and lowercased; unique regardless of case
    * `password` / `password_confirmation` - virtual, only present while a
      password is being set
    * `hashed_password` - bcrypt hash of the password
    * `token_version` - counter embedded in every JWT of the user. A token is
      only valid while its version matches, so incrementing it revokes every
      token issued before (see `Rephi.Accounts.revoke_tokens/1`)
    * `must_change_password` - set by `Rephi.Accounts.reset_password/1`

  The three password fields are redacted, so they never show up when a user
  is inspected or logged.
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

    # Assigned roles and direct permissions only. What a user is allowed to
    # do (inherited roles, permissions through roles) is
    # `Rephi.Authorization.load_access/1`.
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
  Changeset to set a new password.

  It increments `token_version`, which revokes every token issued with the
  previous password (see `Rephi.Accounts.change_password/3`).
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
  Returns the canonical form of an email: trimmed and lowercased.

  Emails are stored and looked up in this form, so `Jane@Example.com ` and
  `jane@example.com` are the same account.
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

  # A new password on an existing account invalidates its outstanding tokens.
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
