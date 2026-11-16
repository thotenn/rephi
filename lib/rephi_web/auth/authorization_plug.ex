defmodule RephiWeb.Auth.AuthorizationPlug do
  @moduledoc """
  Protects controller actions by permission or role.

      defmodule MyAppWeb.ReportController do
        use MyAppWeb, :controller

        plug AuthorizationPlug, {:permission, "reports:view"} when action in [:index, :show]
        plug AuthorizationPlug, {:any_permission, ["reports:create", "reports:edit"]}
        plug AuthorizationPlug, {:all_permissions, ["reports:edit", "reports:publish"]}
        plug AuthorizationPlug, {:role, "manager"}
      end

  `{:role, slug}` follows the role hierarchy, like
  `Rephi.Authorization.has_role?/2`: an `admin` passes `{:role, "manager"}`.
  Prefer permissions: a role check hard-codes who may do something, a
  permission can be granted to any role later.

  The checks read `conn.assigns.current_access`, loaded once per request by
  `RephiWeb.Auth.Pipeline`, so they cost no query. If the conn has a
  `current_user` but no access (a pipeline of your own), it is loaded and
  assigned on the first check.

  ## Responses

    * `401` - nobody is signed in
    * `403` - the user lacks the permission or role

  Both are rendered by `RephiWeb.FallbackController`, in the API error
  envelope: `{"errors": {"detail": "Forbidden"}}`.
  """

  import Plug.Conn

  alias Rephi.Authorization
  alias Rephi.Authorization.Access
  alias RephiWeb.FallbackController

  @doc false
  def init({kind, _} = opts)
      when kind in [:permission, :role, :any_permission, :all_permissions],
      do: opts

  def call(conn, {:permission, slug}), do: authorize(conn, &Authorization.can?(&1, slug))
  def call(conn, {:role, slug}), do: authorize(conn, &Authorization.has_role?(&1, slug))

  def call(conn, {:any_permission, slugs}),
    do: authorize(conn, &Authorization.can_any?(&1, slugs))

  def call(conn, {:all_permissions, slugs}),
    do: authorize(conn, &Authorization.can_all?(&1, slugs))

  @doc """
  Returns the conn with `current_access` assigned for its `current_user`
  (loading it if needed), or the conn untouched when nobody is signed in.
  """
  def ensure_access(conn) do
    case conn.assigns do
      %{current_user: %{id: id}, current_access: %Access{user_id: id}} ->
        conn

      %{current_user: %{} = user} ->
        assign(conn, :current_access, Authorization.load_access(user))

      _ ->
        conn
    end
  end

  # Lets the request through when `allowed?` holds for the current access.
  # Otherwise halts it with a 401 (nobody is signed in) or a 403.
  defp authorize(conn, allowed?) do
    conn = ensure_access(conn)

    case conn.assigns[:current_access] do
      nil -> deny(conn, {:error, :unauthorized, "Authentication required"})
      access -> if allowed?.(access), do: conn, else: deny(conn, {:error, :forbidden})
    end
  end

  defp deny(conn, error) do
    conn
    |> FallbackController.call(error)
    |> halt()
  end
end
