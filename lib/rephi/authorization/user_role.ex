defmodule Rephi.Accounts.UserRole do
  @moduledoc """
  Junction table schema for user-role assignments.

  This schema represents the many-to-many relationship between users and roles,
  with additional metadata about when and why the role was assigned.

  ## Fields

    * `user_id` - Reference to the user
    * `role_id` - Reference to the role
    * `assigned_by` - ID of the user who made the assignment (optional)
    * `notes` - Optional notes about the assignment

  ## Constraints

    * Each user can only have a specific role assigned once
    * Both user_id and role_id must reference valid records

  ## Examples

      iex> changeset = UserRole.changeset(%UserRole{}, %{
      ...>   user_id: 1,
      ...>   role_id: 2,
      ...>   assigned_by: 3,
      ...>   notes: "Promoted to manager role"
      ...> })
      iex> changeset.valid?
      true

  """
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

  @doc """
  Validates and casts user-role assignment attributes.

  ## Required Fields
    * `user_id` - Must reference a valid user
    * `role_id` - Must reference a valid role

  ## Validations
    * Ensures unique combination of user_id and role_id
    * Validates foreign key references

  ## Examples

      iex> UserRole.changeset(%UserRole{}, %{user_id: 1, role_id: 2})
      %Ecto.Changeset{valid?: true}

      iex> UserRole.changeset(%UserRole{}, %{user_id: nil, role_id: nil})
      %Ecto.Changeset{valid?: false}

  """
  def changeset(user_role, attrs) do
    user_role
    |> cast(attrs, [:user_id, :role_id, :assigned_by, :notes])
    |> validate_required([:user_id, :role_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:role_id)
    |> unique_constraint([:user_id, :role_id], name: :user_roles_user_id_role_id_index)
  end
end