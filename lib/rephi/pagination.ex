defmodule Rephi.Pagination do
  @moduledoc """
  Offset pagination for list endpoints.

  `paginate/2` takes an `Ecto.Queryable` with a stable `order_by` and the
  request parameters (`"page"`, `"page_size"`; string or integer values) and
  returns `{:ok, %Rephi.Pagination.Page{}}` or `{:error, changeset}` when a
  parameter is not a positive integer (`RephiWeb.FallbackController` renders
  it as a `422`).

    * `page` starts at 1 (default 1). A page past the end is empty.
    * `page_size` defaults to 50 and is capped at 100: a bigger value is
      not an error, it is lowered to the cap.

  It costs two queries: the total count and the page itself.

      with {:ok, page} <- Rephi.Pagination.paginate(from(u in User, order_by: u.id), params) do
        page.entries
      end
  """
  import Ecto.Changeset
  import Ecto.Query, only: [exclude: 2, limit: 3, offset: 3]

  alias Rephi.Repo

  @default_page_size 50
  @max_page_size 100
  # Keeps `offset` far from the limits of a bigint whatever the client sends.
  @max_page 1_000_000

  defmodule Page do
    @moduledoc "One page of results and where it sits in the whole list."
    @enforce_keys [:entries, :page, :page_size, :total, :total_pages]
    defstruct [:entries, :page, :page_size, :total, :total_pages]

    @type t :: %__MODULE__{
            entries: [term()],
            page: pos_integer(),
            page_size: pos_integer(),
            total: non_neg_integer(),
            total_pages: non_neg_integer()
          }
  end

  @doc "The page size used when the request does not give one."
  def default_page_size, do: @default_page_size

  @doc "The largest page size a request can get."
  def max_page_size, do: @max_page_size

  @doc """
  Runs `queryable` for the page the parameters ask for.
  """
  @spec paginate(Ecto.Queryable.t(), map()) :: {:ok, Page.t()} | {:error, Ecto.Changeset.t()}
  def paginate(queryable, params \\ %{}) do
    with {:ok, %{page: page, page_size: page_size}} <- cast_params(params) do
      total =
        queryable
        |> exclude(:order_by)
        |> exclude(:preload)
        |> Repo.aggregate(:count)

      entries =
        queryable
        |> limit([], ^page_size)
        |> offset([], ^((page - 1) * page_size))
        |> Repo.all()

      {:ok,
       %Page{
         entries: entries,
         page: page,
         page_size: page_size,
         total: total,
         total_pages: div(total + page_size - 1, page_size)
       }}
    end
  end

  @doc """
  Validates `"page"` and `"page_size"`, applying the defaults and the cap.
  """
  @spec cast_params(map()) ::
          {:ok, %{page: pos_integer(), page_size: pos_integer()}} | {:error, Ecto.Changeset.t()}
  def cast_params(params) when is_map(params) do
    types = %{page: :integer, page_size: :integer}
    params = Map.take(params, ["page", "page_size", :page, :page_size])

    {%{page: 1, page_size: @default_page_size}, types}
    |> cast(params, Map.keys(types))
    |> validate_number(:page, greater_than: 0, less_than_or_equal_to: @max_page)
    |> validate_number(:page_size, greater_than: 0)
    |> apply_action(:paginate)
    |> case do
      {:ok, %{page_size: size} = values} ->
        {:ok, %{values | page_size: min(size, @max_page_size)}}

      error ->
        error
    end
  end

  def cast_params(_params), do: cast_params(%{})
end
