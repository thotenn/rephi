defmodule RephiWeb.ControllerHelpersTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset
  import RephiWeb.ControllerHelpers

  defp conn_with_body(body_params) do
    %Plug.Conn{body_params: body_params, params: Map.put(body_params, "id", "7")}
  end

  describe "resource_params/2" do
    test "returns a flat body as it is" do
      conn = conn_with_body(%{"name" => "Editor", "slug" => "editor"})

      assert resource_params(conn, "role") == %{"name" => "Editor", "slug" => "editor"}
    end

    test "unwraps a body wrapped under the resource name" do
      conn = conn_with_body(%{"role" => %{"name" => "Editor"}, "ignored" => true})

      assert resource_params(conn, "role") == %{"name" => "Editor"}
    end

    test "treats a wrapper that is not an object as a flat body" do
      conn = conn_with_body(%{"role" => "admin"})

      assert resource_params(conn, "role") == %{"role" => "admin"}
    end

    test "never includes path or query parameters" do
      refute Map.has_key?(resource_params(conn_with_body(%{"name" => "x"}), "role"), "id")
    end

    test "is an empty map when the body was not parsed" do
      assert resource_params(%Plug.Conn{}, "role") == %{}
    end
  end

  describe "conflict_if_taken/2" do
    defp changeset_with(errors) do
      Enum.reduce(errors, change({%{}, %{user_id: :integer, role_id: :integer}}), fn
        {field, message, opts}, changeset -> add_error(changeset, field, message, opts)
      end)
    end

    test "turns a unique constraint violation into a conflict" do
      changeset = changeset_with([{:user_id, "has already been taken", constraint: :unique}])

      assert conflict_if_taken({:error, changeset}, "Role already assigned to user") ==
               {:error, :conflict, "Role already assigned to user"}
    end

    test "leaves other validation errors untouched" do
      changeset = changeset_with([{:role_id, "does not exist", constraint: :foreign}])

      assert conflict_if_taken({:error, changeset}, "nope") == {:error, changeset}
    end

    test "leaves successes and other errors untouched" do
      assert conflict_if_taken({:ok, :record}, "nope") == {:ok, :record}
      assert conflict_if_taken({:error, :not_found}, "nope") == {:error, :not_found}
    end
  end
end
