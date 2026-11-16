defmodule RephiWeb.FallbackController do
  @moduledoc """
  Turns error values into JSON responses, always in the API error envelope.

  Controllers declare `action_fallback RephiWeb.FallbackController` and simply
  return the error from the action (typically the unmatched clause of a `with`):

      def show(conn, %{"id" => id}) do
        with {:ok, role} <- Authorization.fetch_role(id) do
          render(conn, :show, role: role)
        end
      end

  Supported values:

    * `{:error, %Ecto.Changeset{}}` - `422` with one entry per invalid field:
      `{"errors": {"slug": ["has already been taken"]}}`
    * `{:error, reason}` - a domain error of `Rephi.Authorization` or the
      controllers, with its own status and message (see `domain_errors/0`):
      `{"errors": {"detail": "System roles cannot be deleted"}}`
    * `{:error, status}` - any `Plug.Conn.Status` atom (`:not_found`,
      `:unauthorized`, `:forbidden`, `:conflict`, `:bad_request`…) with the
      standard status text: `{"errors": {"detail": "Not Found"}}`
    * `{:error, status, message}` - the same with a specific message:
      `{"errors": {"detail": "Invalid email or password"}}`

  Plugs that need to stop a request reuse it directly, so there is a single
  place that knows the envelope:

      conn |> RephiWeb.FallbackController.call({:error, :forbidden}) |> halt()
  """
  use RephiWeb, :controller

  alias RephiWeb.{ChangesetJSON, ErrorJSON}

  # Status convention: 403 when the actor lacks the rights for this
  # particular change, 409 when the change conflicts with the current state
  # of the data (it would break an invariant), 422 when a field is invalid
  # (changesets).
  @domain_errors %{
    system_role: {:conflict, "System roles cannot be deleted"},
    system_permission: {:conflict, "System permissions cannot be deleted"},
    last_admin: {:conflict, "At least one user must keep the admin role"},
    self_delete: {:conflict, "You cannot delete your own account"},
    inherited_permission:
      {:conflict,
       "The role inherits this permission from a parent role; revoke it from that role"},
    escalation: {:forbidden, "You can only grant or revoke roles and permissions you hold"},
    outranked: {:forbidden, "You cannot change a user who holds roles you do not hold"}
  }

  @doc """
  The domain error reasons this controller knows, with their status and
  message.
  """
  def domain_errors, do: @domain_errors

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(ChangesetJSON.error(%{changeset: changeset}))
  end

  def call(conn, {:error, reason}) when is_map_key(@domain_errors, reason) do
    {status, message} = Map.fetch!(@domain_errors, reason)
    call(conn, {:error, status, message})
  end

  def call(conn, {:error, status}) when is_atom(status) do
    call(conn, {:error, status, nil})
  end

  def call(conn, {:error, status, detail})
      when is_atom(status) and (is_binary(detail) or is_nil(detail)) do
    code = Plug.Conn.Status.code(status)

    conn
    |> put_status(code)
    |> json(ErrorJSON.render("#{code}.json", %{detail: detail}))
  end
end
