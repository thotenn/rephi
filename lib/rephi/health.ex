defmodule Rephi.Health do
  @moduledoc """
  Readiness checks for `GET /api/health/ready`: one per dependency that must be
  reachable.
  """

  alias Ecto.Adapters.SQL
  alias Rephi.Repo

  @default_timeout 1_000

  @doc """
  Runs a trivial query: `:ok`, or `{:error, :database_unavailable}` within
  `timeout` ms. Never raises, even when no connection can be checked out.
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
