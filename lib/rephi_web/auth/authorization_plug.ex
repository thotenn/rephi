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

  `{:role, slug}` follows the role hierarchy: an `admin` passes `{:role, "manager"}`.
  Failures answer `401` (nobody signed in) or `403`.
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
