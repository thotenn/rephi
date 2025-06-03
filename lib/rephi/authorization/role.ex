defmodule Rephi.Authorization.Role do
  use Ecto.Schema
  import Ecto.Changeset
  alias Rephi.Authorization.{Permission, RolePermission, RoleRole}
  alias Rephi.Accounts.{User, UserRole}

  schema "roles" do
    field :name, :string
    field :slug, :string
    field :description, :string

    many_to_many :permissions, Permission, join_through: RolePermission
    many_to_many :users, User, join_through: UserRole
    
    many_to_many :parent_roles, __MODULE__, join_through: RoleRole,
      join_keys: [child_role_id: :id, parent_role_id: :id]
    
    many_to_many :child_roles, __MODULE__, join_through: RoleRole,
      join_keys: [parent_role_id: :id, child_role_id: :id]

    timestamps()
  end

  @doc false
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :slug, :description])
    |> validate_required([:name, :slug])
    |> unique_constraint(:slug)
    |> validate_format(:slug, ~r/^[a-z0-9_-]+$/, message: "must contain only lowercase letters, numbers, underscores and hyphens")
  end
end