defmodule Rephi.Accounts.UserPermission do
  use Ecto.Schema
  import Ecto.Changeset
  alias Rephi.Accounts.User
  alias Rephi.Authorization.Permission

  schema "user_permissions" do
    belongs_to :user, User
    belongs_to :permission, Permission
    field :assigned_by, :integer
    field :notes, :string

    timestamps()
  end

  @doc false
  def changeset(user_permission, attrs) do
    user_permission
    |> cast(attrs, [:user_id, :permission_id, :assigned_by, :notes])
    |> validate_required([:user_id, :permission_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:permission_id)
    |> unique_constraint([:user_id, :permission_id],
      name: :user_permissions_user_id_permission_id_index
    )
  end
end
