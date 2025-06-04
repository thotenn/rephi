defmodule Rephi.Authorization.RoleRole do
  use Ecto.Schema
  import Ecto.Changeset
  alias Rephi.Authorization.Role

  schema "role_roles" do
    belongs_to :parent_role, Role
    belongs_to :child_role, Role

    timestamps()
  end

  @doc false
  def changeset(role_role, attrs) do
    role_role
    |> cast(attrs, [:parent_role_id, :child_role_id])
    |> validate_required([:parent_role_id, :child_role_id])
    |> foreign_key_constraint(:parent_role_id)
    |> foreign_key_constraint(:child_role_id)
    |> unique_constraint([:parent_role_id, :child_role_id], name: :role_roles_parent_role_id_child_role_id_index)
    |> validate_no_self_reference()
  end

  defp validate_no_self_reference(changeset) do
    case {get_field(changeset, :parent_role_id), get_field(changeset, :child_role_id)} do
      {id, id} when not is_nil(id) ->
        add_error(changeset, :child_role_id, "cannot have itself as parent")
      _ ->
        changeset
    end
  end
end