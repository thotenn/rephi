defmodule Rephi.Authorization.Permission do
  use Ecto.Schema
  import Ecto.Changeset
  alias Rephi.Authorization.{Role, RolePermission, Permission}
  alias Rephi.Accounts.{User, UserPermission}

  schema "permissions" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :parent_id, :id

    belongs_to :parent, Permission, foreign_key: :parent_id, references: :id, define_field: false
    has_many :children, Permission, foreign_key: :parent_id

    many_to_many :roles, Role, join_through: RolePermission
    many_to_many :users, User, join_through: UserPermission

    timestamps()
  end

  @doc false
  def changeset(permission, attrs) do
    permission
    |> cast(attrs, [:name, :slug, :description, :parent_id])
    |> validate_required([:name, :slug])
    |> unique_constraint(:slug)
    |> validate_format(:slug, ~r/^[a-z0-9:_-]+$/, message: "must contain only lowercase letters, numbers, colons, underscores and hyphens")
    |> foreign_key_constraint(:parent_id)
  end
end