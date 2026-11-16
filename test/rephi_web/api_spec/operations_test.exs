defmodule RephiWeb.ApiSpec.OperationsTest do
  use ExUnit.Case, async: true

  import RephiWeb.ApiSpec.Operations

  alias OpenApiSpex.{Header, MediaType, Response, Schema}
  alias RephiWeb.Schemas

  describe "responses/1" do
    test "an error is its description, in the error envelope" do
      %{404 => response} = responses(not_found: "Thing not found")

      assert %Response{description: "Thing not found", content: content} = response
      assert %{"application/json" => %MediaType{schema: Schemas.ErrorResponse}} = content
    end

    test "a 422 gets the validation envelope" do
      assert %{422 => %Response{content: %{"application/json" => media}}} =
               responses(unprocessable_entity: "Invalid name")

      assert media.schema == Schemas.ValidationErrors
    end

    test "a 2xx description is a response without a body" do
      assert responses(no_content: "Deleted") == %{204 => %Response{description: "Deleted"}}
    end

    test "a {description, schema} is a JSON body" do
      assert %{201 => %Response{description: "Created", content: content}} =
               responses(created: {"Created", Schemas.RoleDetailResponse})

      assert content["application/json"].schema == Schemas.RoleDetailResponse
    end

    test "options of a body reach the response" do
      headers = %{"location" => %Header{schema: %Schema{type: :string}}}

      assert %{201 => %Response{headers: ^headers}} =
               responses(created: {"Created", Schemas.RoleDetailResponse, headers: headers})
    end

    test "a response struct is kept as is" do
      response = %Response{description: "Custom"}
      assert responses([{418, response}]) == %{418 => response}
    end

    test "the standard responses" do
      responses = responses([:unauthorized, :body_errors, :invalid_page, :too_many_requests])

      assert Enum.sort(Map.keys(responses)) == [400, 401, 413, 422, 429]
      assert responses[401].description =~ "token"
      assert responses[422].content["application/json"].schema == Schemas.ValidationErrors

      assert %Header{schema: %Schema{type: :integer}} = responses[429].headers["retry-after"]
      assert responses[429].content["application/json"].schema == Schemas.ErrorResponse
    end

    test "an entry of the operation wins over a standard one" do
      responses = responses([:body_errors, bad_request: "Malformed JSON or missing fields"])

      assert responses[400].description == "Malformed JSON or missing fields"
      assert responses[413].description == "Body larger than 1 MB"
    end

    test "an unknown standard response is an error" do
      assert_raise ArgumentError, ~r/unknown standard response :nope/, fn ->
        responses([:nope])
      end
    end
  end

  test "bearer_auth/0 is the bearerAuth scheme of the document" do
    assert bearer_auth() == [%{"bearerAuth" => []}]
    assert Map.has_key?(RephiWeb.ApiSpec.spec().components.securitySchemes, "bearerAuth")
  end

  test "id_param/2 is a required positive integer in the path" do
    assert {:role_id, opts} = id_param(:role_id, "Role ID")
    assert opts[:in] == :path
    assert opts[:required]
    assert opts[:schema] == %Schema{type: :integer, minimum: 1}
  end

  test "page_params/0 are page and page_size in the query" do
    assert [page: page, page_size: page_size] = page_params()
    assert page[:in] == :query and page_size[:in] == :query
  end

  test "body/3 is a JSON body, required unless told otherwise" do
    assert body("The role", Schemas.RoleInput) ==
             {"The role", "application/json", Schemas.RoleInput, [required: true]}

    assert {_, _, _, [required: false]} =
             body("Notes", Schemas.AssignmentNotes, required: false)
  end
end

defmodule RephiWeb.SchemasTest do
  use ExUnit.Case, async: true

  alias OpenApiSpex.Schema
  alias RephiWeb.Schemas

  test "data/2 is the {\"data\": ...} envelope" do
    assert Schemas.data(Schemas.Role, description: "A role") == %{
             type: :object,
             properties: %{data: Schemas.Role},
             required: [:data],
             description: "A role"
           }
  end

  test "page/2 adds the meta of the page to a list" do
    assert %{properties: %{data: data, meta: Schemas.PageMeta}, required: [:data, :meta]} =
             Schemas.page(Schemas.Role)

    assert data == %Schema{type: :array, items: Schemas.Role}
  end

  test "timestamp/1 is a date-time string" do
    assert Schemas.timestamp() == %Schema{type: :string, format: :"date-time"}
    assert Schemas.timestamp(description: "When").description == "When"
  end
end
