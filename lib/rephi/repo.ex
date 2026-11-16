defmodule Rephi.Repo do
  use Ecto.Repo,
    otp_app: :rephi,
    adapter: Ecto.Adapters.Postgres

  # Largest value a PostgreSQL `bigint` primary key can hold.
  @max_id 9_223_372_036_854_775_807

  @doc """
  Fetches a record by its integer primary key without raising.

  Ids usually arrive straight from a URL, so anything that cannot be the id of
  an existing row (`"abc"`, `"1e3"`, `"-1"`, a number that does not fit in a
  `bigint`, `nil`) is reported as missing instead of raising
  `Ecto.Query.CastError` or `DBConnection.EncodeError`.

  ## Examples

      iex> Rephi.Repo.fetch(Rephi.Accounts.User, "42")
      {:ok, %Rephi.Accounts.User{id: 42}}

      iex> Rephi.Repo.fetch(Rephi.Accounts.User, "not-an-id")
      {:error, :not_found}

  """
  @spec fetch(Ecto.Queryable.t(), term()) :: {:ok, Ecto.Schema.t()} | {:error, :not_found}
  def fetch(queryable, id) do
    with {:ok, id} <- cast_id(id),
         %{} = record <- get(queryable, id) do
      {:ok, record}
    else
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Casts a value to a primary key that may exist, or returns `:error`.
  """
  @spec cast_id(term()) :: {:ok, pos_integer()} | :error
  def cast_id(id) do
    case Ecto.Type.cast(:id, id) do
      {:ok, id} when is_integer(id) and id > 0 and id <= @max_id -> {:ok, id}
      _ -> :error
    end
  end
end
