defmodule RephiWeb.PaginationJSON do
  @moduledoc """
  Renders a `Rephi.Pagination.Page` in the shape every paginated endpoint
  shares:

      {"data": [...], "meta": {"page": 1, "page_size": 50, "total": 120, "total_pages": 3}}

  A client that only reads `data` keeps working; it just sees the first page.
  """

  alias Rephi.Pagination.Page

  @doc """
  Renders the page, each entry through `render_entry`.
  """
  def render(%Page{} = page, render_entry) when is_function(render_entry, 1) do
    %{data: Enum.map(page.entries, render_entry), meta: meta(page)}
  end

  @doc """
  The `meta` object of a page.
  """
  def meta(%Page{} = page) do
    %{
      page: page.page,
      page_size: page.page_size,
      total: page.total,
      total_pages: page.total_pages
    }
  end

  @doc """
  Swagger definitions shared by the paginated endpoints.
  """
  def swagger_definitions do
    %{
      PageMeta: %{
        type: :object,
        title: "Page Meta",
        description: "Where a page sits in the whole list",
        properties: %{
          page: %{type: :integer, description: "Current page, from 1"},
          page_size: %{type: :integer, description: "Entries per page (at most 100)"},
          total: %{type: :integer, description: "Entries in the whole list"},
          total_pages: %{type: :integer, description: "Number of pages"}
        },
        required: [:page, :page_size, :total, :total_pages],
        example: %{page: 1, page_size: 50, total: 3, total_pages: 1}
      }
    }
  end
end
