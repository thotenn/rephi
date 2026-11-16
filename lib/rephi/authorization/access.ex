defmodule Rephi.Authorization.Access do
  @moduledoc """
  Everything a user is allowed to do, loaded at once.

  `Rephi.Authorization.load_access/1` builds it in a single query.
  `RephiWeb.Auth.Pipeline` loads it once per authenticated request into
  `conn.assigns.current_access`, and every check of that request
  (`RephiWeb.Auth.AuthorizationPlug`, `RephiWeb.Auth.AuthorizationHelpers`,
  `/api/me`, the claims of a new token) reads it without touching the
  database:

      Authorization.can?(conn.assigns.current_access, "users:edit")

  The functions of `Rephi.Authorization` that take a user (`can?/2`,
  `can_any?/2`, `can_all?/2`, `has_role?/2`, `has_direct_role?/2`) accept an
  `Access` in its place.

  ## Fields

    * `user_id`
    * `roles` - the roles assigned to the user, sorted by slug
    * `role_slugs` - slugs of the roles the user holds: the assigned ones and
      all their ancestors in the hierarchy
    * `permissions` - the effective permissions (direct, through a role, or
      inherited from an ancestor role), sorted by slug
    * `permission_slugs` - their slugs

  `roles` and `permissions` hold `%{id, name, slug}` maps, not full structs.

  An `Access` is a snapshot: a role granted later in the same request is not
  in it. Load a new one if a request needs to see its own changes.
  """

  @type grant :: %{id: pos_integer(), name: String.t(), slug: String.t()}

  @type t :: %__MODULE__{
          user_id: pos_integer() | nil,
          roles: [grant()],
          role_slugs: MapSet.t(String.t()),
          permissions: [grant()],
          permission_slugs: MapSet.t(String.t())
        }

  defstruct user_id: nil,
            roles: [],
            role_slugs: MapSet.new(),
            permissions: [],
            permission_slugs: MapSet.new()
end
