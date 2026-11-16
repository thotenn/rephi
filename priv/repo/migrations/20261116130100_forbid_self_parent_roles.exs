defmodule Rephi.Repo.Migrations.ForbidSelfParentRoles do
  @moduledoc """
  A role can never be its own parent; existing self-links grant nothing and are
  deleted. Longer cycles are rejected by `Rephi.Authorization`.
  """
  use Ecto.Migration

  def up do
    execute "DELETE FROM role_roles WHERE parent_role_id = child_role_id"

    create constraint(:role_roles, :role_roles_no_self_parent,
             check: "parent_role_id <> child_role_id"
           )
  end

  def down do
    drop constraint(:role_roles, :role_roles_no_self_parent)
  end
end
