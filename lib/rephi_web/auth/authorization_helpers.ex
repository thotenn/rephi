defmodule RephiWeb.Auth.AuthorizationHelpers do
  @moduledoc """
  Authorization checks for the body of a controller action, imported by
  `use RephiWeb, :controller`.

  They read `conn.assigns.current_access`, loaded once per request by
  `RephiWeb.Auth.Pipeline`, so they cost no query. Without a signed-in user
  every check is `false`.

      def show(conn, %{"id" => id}) do
        with {:ok, report} <- Reports.fetch_report(id) do
          render(conn, :show, report: report, can_edit: can?(conn, "reports:edit"))
        end
      end

      def publish(conn, params) do
        with true <- can_all?(conn, ["reports:edit", "reports:publish"]) || {:error, :forbidden},
             ... do
        end
      end

  To guard a whole action, use `RephiWeb.Auth.AuthorizationPlug` instead.
  """

  alias Rephi.Authorization
  alias Rephi.Authorization.Access

  @doc """
  The `Rephi.Authorization.Access` of the signed-in user, or `nil`.

  It comes from the conn when the pipeline loaded it; otherwise it is loaded
  (one query, not stored: the helpers return booleans, not a conn).
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
