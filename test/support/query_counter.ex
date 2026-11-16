defmodule Rephi.QueryCounter do
  @moduledoc """
  Counts the SQL queries a piece of code runs, through the
  `[:rephi, :repo, :query]` telemetry event.

  Only queries run by the calling process, or by tasks it spawned (Ecto runs
  parallel preloads that way), count: Ecto emits the event in the process
  that runs the query and `Phoenix.ConnTest` dispatches requests in the test
  process, so it is safe in `async: true` tests. Transaction
  control statements (`begin`, `commit`, savepoints) do not count.

      {result, 1} = count_queries(fn -> Authorization.can?(user, "x:y") end)
      assert queries(fn -> get(conn, "/api/me") end) |> length() == 2
  """

  @control ~r/\A\s*(begin|commit|rollback|savepoint|release)\b/i

  @doc """
  Runs `fun` and returns `{result, number_of_queries}`.
  """
  def count_queries(fun) when is_function(fun, 0) do
    {result, queries} = capture(fun)
    {result, length(queries)}
  end

  @doc """
  Runs `fun` and returns the SQL of the queries it ran, in order.
  """
  def queries(fun) when is_function(fun, 0) do
    fun |> capture() |> elem(1)
  end

  defp capture(fun) do
    test_pid = self()
    ref = make_ref()
    handler_id = {__MODULE__, ref}

    :ok =
      :telemetry.attach(
        handler_id,
        [:rephi, :repo, :query],
        &__MODULE__.handle_event/4,
        %{pid: test_pid, ref: ref}
      )

    try do
      result = fun.()
      {result, drain(ref, [])}
    after
      :telemetry.detach(handler_id)
    end
  end

  @doc false
  def handle_event(_event, _measurements, metadata, %{pid: pid, ref: ref}) do
    query = metadata[:query] || ""

    if from_caller?(pid) and not Regex.match?(@control, query) do
      send(pid, {ref, query})
    end
  end

  # Ecto runs some queries (several preloads) in tasks spawned by the caller.
  defp from_caller?(pid), do: self() == pid or pid in (Process.get(:"$callers") || [])

  defp drain(ref, acc) do
    receive do
      {^ref, query} -> drain(ref, [query | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
