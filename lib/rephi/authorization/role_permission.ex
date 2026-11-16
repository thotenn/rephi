defmodule Rephi.Authorization.RolePermission do
  @moduledoc """
  A permission granted to a role. `assigned_by` is the user who granted it
  (cleared if that user is deleted).
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Rephi.Accounts.User
  alias Rephi.Authorization.{Permission, Role}

  schema "role_permissions" do
    belongs_to :role, Role
    belongs_to :permission, Permission
    belongs_to :assigner, User, foreign_key: :assigned_by
    field :notes, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(role_permission, attrs) do
    role_permission
    |> cast(attrs, [:role_id, :permission_id, :assigned_by, :notes])
    |> validate_required([:role_id, :permission_id])
    |> validate_length(:notes, max: 2000)
    |> foreign_key_constraint(:role_id)
    |> foreign_key_constraint(:permission_id)
    |> foreign_key_constraint(:assigned_by)
    |> unique_constraint([:role_id, :permission_id],
      name: :role_permissions_role_id_permission_id_index
    )
  end
end
