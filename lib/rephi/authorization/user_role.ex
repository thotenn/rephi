defmodule Rephi.Authorization.UserRole do
  @moduledoc """
  A role assigned to a user. `assigned_by` is the user who assigned it
  (cleared if that user is deleted); `notes` is free text.

  Each user holds a given role at most once.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Rephi.Accounts.User
  alias Rephi.Authorization.Role

  schema "user_roles" do
    belongs_to :user, User
    belongs_to :role, Role
    belongs_to :assigner, User, foreign_key: :assigned_by
    field :notes, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_role, attrs) do
    user_role
    |> cast(attrs, [:user_id, :role_id, :assigned_by, :notes])
    |> validate_required([:user_id, :role_id])
    |> validate_length(:notes, max: 2000)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:role_id)
    |> foreign_key_constraint(:assigned_by)
    |> unique_constraint([:user_id, :role_id], name: :user_roles_user_id_role_id_index)
  end
end
