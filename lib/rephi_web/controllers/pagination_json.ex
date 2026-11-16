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
end
