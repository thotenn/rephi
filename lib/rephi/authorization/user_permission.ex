defmodule Rephi.Authorization.UserPermission do
  @moduledoc """
  A permission granted directly to a user, on top of what its roles grant.
  `assigned_by` is the user who granted it (cleared if that user is deleted).
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Rephi.Accounts.User
  alias Rephi.Authorization.Permission

  schema "user_permissions" do
    belongs_to :user, User
    belongs_to :permission, Permission
    belongs_to :assigner, User, foreign_key: :assigned_by
    field :notes, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_permission, attrs) do
    user_permission
    |> cast(attrs, [:user_id, :permission_id, :assigned_by, :notes])
    |> validate_required([:user_id, :permission_id])
    |> validate_length(:notes, max: 2000)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:permission_id)
    |> foreign_key_constraint(:assigned_by)
    |> unique_constraint([:user_id, :permission_id],
      name: :user_permissions_user_id_permission_id_index
    )
  end
end
