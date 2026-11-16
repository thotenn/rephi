defmodule RephiWeb.ControllerHelpers do
  @moduledoc """
  Small conveniences shared by the JSON controllers.

  Imported by `use RephiWeb, :controller`.
  """

  alias Plug.Conn

  @doc """
  Returns the attributes sent in the body of a write request.

  Clients may send them flat or wrapped under the resource name; both are
  accepted on every write endpoint:

      {"name": "Editor", "slug": "editor"}
      {"role": {"name": "Editor", "slug": "editor"}}

  Only the request body is considered, so path and query parameters never leak
  into the attributes.

  ## Examples

      def create(conn, _params) do
        with {:ok, role} <- Authorization.create_role(resource_params(conn, "role")) do
          ...
        end
      end

  """
  @spec resource_params(Conn.t(), String.t()) :: map()
  def resource_params(%Conn{body_params: body_params}, key) when is_binary(key) do
    case body_params do
      %{^key => %{} = wrapped} -> wrapped
      %Conn.Unfetched{} -> %{}
      %{} = flat -> flat
    end
  end

  @doc """
  Maps the result of an insert that hit a unique constraint to a `409 Conflict`.

  Meant for "link" endpoints (assign a role to a user, a permission to a
  role…) where a duplicate is not a validation problem of any field: the
  relationship already exists. Any other result is returned untouched.

  ## Examples

      with {:ok, user_role} <-
             user
             |> Authorization.assign_role_to_user(role)
             |> conflict_if_taken("Role already assigned to user") do
        ...
      end

  """
  @spec conflict_if_taken(result, String.t()) :: result | {:error, :conflict, String.t()}
        when result: {:ok, term()} | {:error, term()}
  def conflict_if_taken({:error, %Ecto.Changeset{} = changeset} = result, message) do
    if unique_violation?(changeset), do: {:error, :conflict, message}, else: result
  end

  def conflict_if_taken(result, _message), do: result

  defp unique_violation?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn {_field, {_message, opts}} -> opts[:constraint] == :unique end)
  end
end
