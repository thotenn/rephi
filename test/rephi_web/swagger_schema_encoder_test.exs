defmodule RephiWeb.SwaggerSchemaEncoderTest do
  use ExUnit.Case, async: true

  test "a schema reference inside a plain map encodes as a JSON reference" do
    definitions = %{
      "UserResponse" => %{
        "type" => "object",
        "properties" => %{"data" => PhoenixSwagger.Schema.ref(:User)}
      }
    }

    assert Jason.decode!(Jason.encode!(definitions)) == %{
             "UserResponse" => %{
               "type" => "object",
               "properties" => %{"data" => %{"$ref" => "#/definitions/User"}}
             }
           }
  end

  test "every controller's swagger definitions encode" do
    controllers =
      for controller <- [
            RephiWeb.AuthController,
            RephiWeb.UserController,
            RephiWeb.RoleController,
            RephiWeb.PermissionController
          ],
          Code.ensure_loaded!(controller),
          function_exported?(controller, :swagger_definitions, 0) do
        assert {:ok, _json} = Jason.encode(controller.swagger_definitions())
        controller
      end

    assert controllers != []
  end
end
