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

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(ChangesetJSON.error(%{changeset: changeset}))
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
