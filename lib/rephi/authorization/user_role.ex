defmodule Rephi.Accounts.UserRole do
  use Ecto.Schema
  import Ecto.Changeset
  alias Rephi.Accounts.User
  alias Rephi.Authorization.Role

  schema "user_roles" do
    belongs_to :user, User
    belongs_to :role, Role
    field :assigned_by, :integer
    field :notes, :string

    timestamps()
  end

  @doc false
  def changeset(user_role, attrs) do
    user_role
    |> cast(attrs, [:user_id, :role_id, :assigned_by, :notes])
    |> validate_required([:user_id, :role_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:role_id)
    |> unique_constraint([:user_id, :role_id], name: :user_roles_user_id_role_id_index)
  end
end