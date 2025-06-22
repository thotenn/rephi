defmodule Rephi.Authorization.Role do
  @moduledoc """
  Schema and validations for roles in the authorization system.

  Roles represent a collection of permissions that can be assigned to users.
  Roles support hierarchical inheritance, where child roles can inherit 
  permissions from parent roles.

  ## Fields

    * `name` - Human-readable role name (e.g., "Administrator")
    * `slug` - Unique identifier for the role (e.g., "admin")
    * `description` - Optional description of the role's purpose

  ## Associations

    * `permissions` - Permissions directly assigned to this role
    * `users` - Users who have this role assigned
    * `parent_roles` - Roles this role inherits from
    * `child_roles` - Roles that inherit from this role

  ## Examples

      iex> changeset = Role.changeset(%Role{}, %{
      ...>   name: "Content Manager",
      ...>   slug: "content_manager",
      ...>   description: "Can manage content and media"
      ...> })
      iex> changeset.valid?
      true

  """
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

    many_to_many :parent_roles, __MODULE__,
      join_through: RoleRole,
      join_keys: [child_role_id: :id, parent_role_id: :id]

    many_to_many :child_roles, __MODULE__,
      join_through: RoleRole,
      join_keys: [parent_role_id: :id, child_role_id: :id]

    timestamps()
  end

  @doc """
  Validates and casts role attributes.

  ## Required Fields
    * `name` - Must be present
    * `slug` - Must be present and unique

  ## Validations
    * `slug` must contain only lowercase letters, numbers, underscores, and hyphens
    * `slug` must be unique across all roles

  ## Examples

      iex> Role.changeset(%Role{}, %{name: "Admin", slug: "admin"})
      %Ecto.Changeset{valid?: true}

      iex> Role.changeset(%Role{}, %{name: "", slug: ""})
      %Ecto.Changeset{valid?: false}

      iex> Role.changeset(%Role{}, %{name: "Test", slug: "Invalid-Slug!"})
      %Ecto.Changeset{valid?: false}

  """
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :slug, :description])
    |> validate_required([:name, :slug])
    |> unique_constraint(:slug)
    |> validate_format(:slug, ~r/^[a-z0-9_-]+$/,
      message: "must contain only lowercase letters, numbers, underscores and hyphens"
    )
  end
end
