defmodule Rephi.Health do
  @moduledoc """
  Checks whether the application can do its job right now.

  Used by the readiness endpoint (`GET /api/health/ready`), which load
  balancers and orchestrators poll to decide if an instance should receive
  traffic. Add a function here for every dependency that must be reachable
  (cache, message broker, third-party API…).
  """

  alias Ecto.Adapters.SQL
  alias Rephi.Repo

  @default_timeout 1_000

  @doc """
  Runs a trivial query against the database.

  Returns `:ok`, or `{:error, :database_unavailable}` when the query fails or
  does not answer within `timeout` milliseconds. It never raises and never
  takes longer than `timeout`, even when no connection can be checked out of
  the pool.
  """
  @spec check_database(timeout :: pos_integer()) :: :ok | {:error, :database_unavailable}
  def check_database(timeout \\ @default_timeout) do
    task = Task.async(fn -> ping(timeout) end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, :ok} -> :ok
      _ -> {:error, :database_unavailable}
    end
  end

  defp ping(timeout) do
    case SQL.query(Repo, "SELECT 1", [], timeout: timeout, log: false) do
      {:ok, _result} -> :ok
      {:error, _reason} -> :error
    end
  rescue
    _exception -> :error
  catch
    _kind, _reason -> :error
  end
end
