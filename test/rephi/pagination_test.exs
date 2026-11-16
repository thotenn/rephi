defmodule Rephi.PaginationTest do
  @moduledoc "RBAC-18."
  use Rephi.DataCase, async: true

  import Rephi.AuthTestHelpers

  alias Rephi.Accounts.User
  alias Rephi.Pagination

  test "defaults, cap and validation of the parameters" do
    assert Pagination.cast_params(%{}) == {:ok, %{page: 1, page_size: 50}}

    assert Pagination.cast_params(%{"page" => "3", "page_size" => "7"}) ==
             {:ok, %{page: 3, page_size: 7}}

    assert Pagination.cast_params(%{"page_size" => 1000}) == {:ok, %{page: 1, page_size: 100}}
    assert Pagination.cast_params(nil) == {:ok, %{page: 1, page_size: 50}}
    assert Pagination.cast_params(%{"other" => "x"}) == {:ok, %{page: 1, page_size: 50}}

    for params <- [
          %{"page" => "0"},
          %{"page" => "-1"},
          %{"page" => "x"},
          %{"page" => "99999999999999999999"},
          %{"page_size" => "0"},
          %{"page_size" => []}
        ] do
      assert {:error, %Ecto.Changeset{}} = Pagination.cast_params(params), inspect(params)
    end
  end

  test "pages through an ordered query" do
    ids = for _ <- 1..5, do: create_user().id
    query = from(u in User, order_by: [desc: u.id], select: u.id)

    assert {:ok, page} = Pagination.paginate(query, %{"page" => 2, "page_size" => 2})
    assert page.entries == ids |> Enum.reverse() |> Enum.slice(2, 2)
    assert {page.page, page.page_size, page.total, page.total_pages} == {2, 2, 5, 3}

    assert {:ok, %{entries: [], total: 5}} =
             Pagination.paginate(query, %{"page" => 4, "page_size" => 2})
  end
end
