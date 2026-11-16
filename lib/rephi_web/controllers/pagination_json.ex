defmodule RephiWeb.PaginationJSON do
  @moduledoc """
  Renders a `Rephi.Pagination.Page` as
  `{"data": [...], "meta": {"page", "page_size", "total", "total_pages"}}`.
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
