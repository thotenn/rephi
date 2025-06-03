defmodule Rephi.Authorization.RolePermission do
  use Ecto.Schema
  import Ecto.Changeset
  alias Rephi.Authorization.{Role, Permission}

  schema "role_permissions" do
    belongs_to :role, Role
    belongs_to :permission, Permission
    field :assigned_by, :integer
    field :notes, :string

    timestamps()
  end

  @doc false
  def changeset(role_permission, attrs) do
    role_permission
    |> cast(attrs, [:role_id, :permission_id, :assigned_by, :notes])
    |> validate_required([:role_id, :permission_id])
    |> foreign_key_constraint(:role_id)
    |> foreign_key_constraint(:permission_id)
    |> unique_constraint([:role_id, :permission_id], name: :role_permissions_role_id_permission_id_index)
  end
end