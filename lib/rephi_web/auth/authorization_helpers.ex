defmodule RephiWeb.Auth.AuthorizationHelpers do
  @moduledoc """
  Authorization checks for the body of a controller action, imported by
  `use RephiWeb, :controller`. To guard a whole action, use
  `RephiWeb.Auth.AuthorizationPlug`.
  """

  alias Rephi.Authorization
  alias Rephi.Authorization.Access

  @doc """
  The `Rephi.Authorization.Access` of the signed-in user (loaded if the pipeline
  did not), or `nil`.
  """
  @spec current_access(Plug.Conn.t()) :: Access.t() | nil
  def current_access(conn) do
    case conn.assigns do
      %{current_user: %{id: id}, current_access: %Access{user_id: id} = access} -> access
      %{current_user: %{} = user} -> Authorization.load_access(user)
      _ -> nil
    end
  end

  @doc """
  Whether the signed-in user holds the permission (see
  `Rephi.Authorization.can?/2`).
  """
  def can?(conn, permission_slug), do: Authorization.can?(current_access(conn), permission_slug)

  @doc """
  Whether the signed-in user holds the role, assigned or inherited (see
  `Rephi.Authorization.has_role?/2`).
  """
  def has_role?(conn, role_slug), do: Authorization.has_role?(current_access(conn), role_slug)

  @doc """
  Whether the signed-in user holds at least one of the permissions.
  """
  def can_any?(conn, permission_slugs),
    do: Authorization.can_any?(current_access(conn), permission_slugs)

  @doc """
  Whether the signed-in user holds every one of the permissions.
  """
  def can_all?(conn, permission_slugs),
    do: Authorization.can_all?(current_access(conn), permission_slugs)
end
