defmodule Rephi.Authorization.RoleRole do
  @moduledoc """
  Role hierarchy: the child role inherits every permission of the parent role.

  A role cannot be its own parent (validated here and by the
  `role_roles_no_self_parent` check constraint). Longer cycles are rejected by
  `Rephi.Authorization.assign_parent_role/2`, which is the only supported way
  to insert rows.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Rephi.Authorization.Role

  schema "role_roles" do
    belongs_to :parent_role, Role
    belongs_to :child_role, Role

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(role_role, attrs) do
    role_role
    |> cast(attrs, [:parent_role_id, :child_role_id])
    |> validate_required([:parent_role_id, :child_role_id])
    |> validate_no_self_reference()
    |> foreign_key_constraint(:parent_role_id)
    |> foreign_key_constraint(:child_role_id)
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
        add_error(changeset, :parent_role_id, "cannot be the role itself")

      _ ->
        changeset
    end
  end
end
