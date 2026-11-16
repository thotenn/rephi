defmodule RephiWeb.FallbackController do
  @moduledoc """
  Renders `{:error, changeset | reason | status}` and `{:error, status, message}`
  in the API error envelope. Plugs reuse it:
  `conn |> RephiWeb.FallbackController.call({:error, :forbidden}) |> halt()`.
  """
  use RephiWeb, :controller

  alias RephiWeb.{ChangesetJSON, ErrorJSON}

  # 403: the actor lacks the rights for this change; 409: it would break an
  # invariant of the data; 422: a field is invalid.
  @domain_errors %{
    system_role: {:conflict, "System roles cannot be deleted"},
    system_permission: {:conflict, "System permissions cannot be deleted"},
    last_admin: {:conflict, "At least one user must keep the admin role"},
    self_delete: {:conflict, "You cannot delete your own account"},
    self_password_reset:
      {:conflict, "You cannot reset your own password; change it with PUT /api/me/password"},
    inherited_permission:
      {:conflict,
       "The role inherits this permission from a parent role; revoke it from that role"},
    granted_through_role:
      {:conflict,
       "The user holds this permission through a role; revoke it from the role or remove the role from the user"},
    system_link: {:conflict, "Links of the default role hierarchy cannot be removed"},
    hierarchy_cycle: {:conflict, "The role would inherit from itself"},
    escalation: {:forbidden, "You can only grant or revoke roles and permissions you hold"},
    outranked: {:forbidden, "You cannot change a user who holds roles you do not hold"},
    password_change_required:
      {:forbidden,
       "Your password was reset: set a new one with PUT /api/me/password before continuing"}
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
