defmodule Rephi.Authorization.RoleRole do
  @moduledoc """
  Role hierarchy: the child role inherits every permission of the parent role.

  A role cannot be its own parent (validated here and by the
  `role_roles_no_self_parent` check constraint). Longer cycles are rejected by
  `Rephi.Authorization.assign_parent_role/3`, which is the only supported way
  to insert rows.

  `is_system` marks the seeded links, which cannot be removed.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Rephi.Accounts.User
  alias Rephi.Authorization.Role

  schema "role_roles" do
    belongs_to :parent_role, Role
    belongs_to :child_role, Role
    belongs_to :assigner, User, foreign_key: :assigned_by
    field :notes, :string
    field :is_system, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(role_role, attrs) do
    role_role
    |> cast(attrs, [:parent_role_id, :child_role_id, :assigned_by, :notes])
    |> validate_required([:parent_role_id, :child_role_id])
    |> validate_length(:notes, max: 2000)
    |> validate_no_self_reference()
    |> foreign_key_constraint(:parent_role_id)
    |> foreign_key_constraint(:child_role_id)
    |> foreign_key_constraint(:assigned_by)
    |> check_constraint(:parent_role_id,
      name: :role_roles_no_self_parent,
      message: "cannot be the role itself"
    )
    |> unique_constraint([:parent_role_id, :child_role_id],
      name: :role_roles_parent_role_id_child_role_id_index
    )
  end

  defp validate_no_self_reference(changeset) do
    case {get_field(changeset, :parent_role_id), get_field(changeset, :child_role_id)} do
      {id, id} when not is_nil(id) ->
        add_error(changeset, :parent_role_id, "cannot be the role itself", validation: :cycle)

      _ ->
        changeset
    end
  end
end
