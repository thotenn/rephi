defmodule Rephi.Authorization.Permission do
  @moduledoc """
  Schema and validations for permissions in the authorization system.

  Permissions represent granular access rights that can be assigned to roles
  or directly to users. Permissions support hierarchical organization where
  child permissions can inherit from parent permissions.

  ## Fields

    * `name` - Human-readable permission name (e.g., "View Users")
    * `slug` - Unique identifier using colon notation (e.g., "users:view")
    * `description` - Optional description of what the permission allows
    * `parent_id` - Optional reference to parent permission for hierarchy

  ## Permission Naming Convention

  Permissions use colon notation to organize by domain:
  - `users:view` - View user information
  - `users:create` - Create new users
  - `roles:edit` - Edit role information
  - `system:manage` - System administration

  ## Associations

    * `parent` - Parent permission in hierarchy
    * `children` - Child permissions that inherit from this one
    * `roles` - Roles that have this permission assigned
    * `users` - Users who have this permission directly assigned

  ## Examples

      iex> changeset = Permission.changeset(%Permission{}, %{
      ...>   name: "View Users",
      ...>   slug: "users:view",
      ...>   description: "Allows viewing user profiles and listings"
      ...> })
      iex> changeset.valid?
      true

  """
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

  @doc """
  Validates and casts permission attributes.

  ## Required Fields
    * `name` - Must be present
    * `slug` - Must be present and unique

  ## Validations
    * `slug` must contain only lowercase letters, numbers, colons, underscores, and hyphens
    * `slug` must be unique across all permissions
    * `parent_id` must reference a valid permission if provided

  ## Examples

      iex> Permission.changeset(%Permission{}, %{
      ...>   name: "Edit Users", 
      ...>   slug: "users:edit"
      ...> })
      %Ecto.Changeset{valid?: true}

      iex> Permission.changeset(%Permission{}, %{name: "", slug: ""})
      %Ecto.Changeset{valid?: false}

      iex> Permission.changeset(%Permission{}, %{
      ...>   name: "Test", 
      ...>   slug: "Invalid Slug!"
      ...> })
      %Ecto.Changeset{valid?: false}

  """
  def changeset(permission, attrs) do
    permission
    |> cast(attrs, [:name, :slug, :description, :parent_id])
    |> validate_required([:name, :slug])
    |> unique_constraint(:slug)
    |> validate_format(:slug, ~r/^[a-z0-9:_-]+$/,
      message: "must contain only lowercase letters, numbers, colons, underscores and hyphens"
    )
    |> foreign_key_constraint(:parent_id)
  end
end
