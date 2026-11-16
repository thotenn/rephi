defmodule Rephi.Authorization.Role do
  @moduledoc """
  A named set of permissions that can be assigned to users.

  ## Fields

    * `name` - human-readable name (`"Administrator"`), at most 255 characters
    * `slug` - unique identifier that code refers to (`"admin"`): lowercase
      letters and digits, words separated by `_` or `-`, at most 100
      characters
    * `description` - optional, at most 2000 characters
    * `is_system` - the role is part of the application (created by
      `Rephi.Seeds`): it cannot be deleted and its slug cannot change. It is
      never set from user input.

  ## Hierarchy

  A role can have parent roles (`role_roles`): it grants its own permissions
  plus every permission of its ancestors, transitively. Holding a role also
  means holding all its ancestors, for `Rephi.Authorization.has_role?/2`.
  See `Rephi.Authorization.assign_parent_role/2`.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Rephi.Accounts.User
  alias Rephi.Authorization.{Permission, RolePermission, RoleRole, UserRole}

  @slug_format ~r/\A[a-z0-9]+(?:[_-][a-z0-9]+)*\z/

  schema "roles" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :is_system, :boolean, default: false

    many_to_many :permissions, Permission, join_through: RolePermission
    many_to_many :users, User, join_through: UserRole

    many_to_many :parent_roles, __MODULE__,
      join_through: RoleRole,
      join_keys: [child_role_id: :id, parent_role_id: :id]

    many_to_many :child_roles, __MODULE__,
      join_through: RoleRole,
      join_keys: [parent_role_id: :id, child_role_id: :id]

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset to create a role.

      iex> Role.create_changeset(%Role{}, %{name: "Editor", slug: "editor"}).valid?
      true

      iex> Role.create_changeset(%Role{}, %{name: "Editor", slug: "Editor!"}).valid?
      false

  """
  def create_changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :slug, :description])
    |> validate()
  end

  @doc """
  Changeset to update a role. The slug of a system role cannot change.
  """
  def update_changeset(%__MODULE__{} = role, attrs) do
    role
    |> cast(attrs, [:name, :slug, :description])
    |> validate()
    |> validate_system_slug()
  end

  defp validate(changeset) do
    changeset
    |> validate_required([:name, :slug])
    |> validate_length(:name, max: 255)
    |> validate_length(:slug, max: 100)
    |> validate_length(:description, max: 2000)
    |> validate_format(:slug, @slug_format,
      message: "must be lowercase letters and digits, words separated by _ or -"
    )
    |> unique_constraint(:slug)
  end

  defp validate_system_slug(%Ecto.Changeset{data: %{is_system: true}} = changeset) do
    if get_change(changeset, :slug),
      do: add_error(changeset, :slug, "cannot be changed on a system role"),
      else: changeset
  end

  defp validate_system_slug(changeset), do: changeset
end
