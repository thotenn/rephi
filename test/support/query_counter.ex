defmodule Rephi.QueryCounter do
  @moduledoc """
  Counts the SQL queries run by the calling process and the tasks it spawned
  (`[:rephi, :repo, :query]` telemetry), so it is safe in `async: true` tests.
  Transaction control statements do not count.
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
