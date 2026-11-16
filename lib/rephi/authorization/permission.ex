defmodule Rephi.Authorization.Permission do
  @moduledoc """
  A single access right (`"users:view"`), granted to roles or directly to users.
  There are no wildcards, and `parent_id` only groups permissions for display:
  holding a parent grants none of its children.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Rephi.Accounts.User
  alias Rephi.Authorization.{RolePermission, Role, UserPermission}

  @slug_format ~r/\A[a-z0-9]+(?:[_-][a-z0-9]+)*(?::[a-z0-9]+(?:[_-][a-z0-9]+)*)+\z/

  schema "permissions" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :is_system, :boolean, default: false

    belongs_to :parent, __MODULE__, foreign_key: :parent_id
    has_many :children, __MODULE__, foreign_key: :parent_id

    many_to_many :roles, Role, join_through: RolePermission
    many_to_many :users, User, join_through: UserPermission

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset to create a permission.
  """
  def create_changeset(permission, attrs) do
    permission
    |> cast(attrs, [:name, :slug, :description, :parent_id])
    |> validate()
  end

  @doc """
  Changeset to update a permission. The slug of a system permission cannot
  change.
  """
  def update_changeset(%__MODULE__{} = permission, attrs) do
    permission
    |> cast(attrs, [:name, :slug, :description, :parent_id])
    |> validate()
    |> validate_not_own_parent()
    |> validate_system_slug()
  end

  defp validate(changeset) do
    changeset
    |> validate_required([:name, :slug])
    |> validate_length(:name, max: 255)
    |> validate_length(:slug, max: 100)
    |> validate_length(:description, max: 2000)
    |> validate_format(:slug, @slug_format,
      message: "must be category:action, lowercase letters and digits"
    )
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:parent_id)
    |> check_constraint(:parent_id,
      name: :permissions_not_own_parent,
      message: "cannot be the permission itself"
    )
  end

  defp validate_not_own_parent(%Ecto.Changeset{data: %{id: id}} = changeset) do
    if id && get_field(changeset, :parent_id) == id,
      do: add_error(changeset, :parent_id, "cannot be the permission itself"),
      else: changeset
  end

  defp validate_system_slug(%Ecto.Changeset{data: %{is_system: true}} = changeset) do
    if get_change(changeset, :slug),
      do: add_error(changeset, :slug, "cannot be changed on a system permission"),
      else: changeset
  end

  defp validate_system_slug(changeset), do: changeset
end
