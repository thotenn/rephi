defmodule Rephi.Repo.Migrations.ForbidSelfParentRoles do
  @moduledoc """
  A role can never be its own parent.

  `Rephi.Authorization.assign_parent_role/2` also rejects longer cycles; this
  constraint is the part the database can enforce on its own, even for rows
  inserted without going through the application. A self-link has no effect
  on what a role grants, so existing ones are deleted before the constraint
  is added.
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
