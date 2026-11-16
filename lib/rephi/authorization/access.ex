defmodule Rephi.Authorization.Access do
  @moduledoc """
  Everything a user may do (`user_id`, `roles`, `role_slugs`, `permissions`,
  `permission_slugs`), loaded in one query by `Rephi.Authorization.load_access/1`
  and accepted by its checks in place of a user. A snapshot: changes made later
  in the same request are not in it.
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
