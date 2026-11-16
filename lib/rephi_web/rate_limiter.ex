defmodule RephiWeb.RateLimiter do
  @moduledoc """
  Fixed-window request counter kept in an ETS table.

  It answers one question: "has this key been seen more than `limit` times in
  the current window?". `RephiWeb.Plugs.RateLimit` is the plug built on it;
  call `hit/3` directly to throttle anything else (a channel event, a job).

  The process only owns the table and removes expired entries once a minute.
  Counting happens in the caller, with atomic ETS updates, so the limiter is
  never a bottleneck.

  Counters live in the memory of one node and are lost on restart. With
  several nodes each one counts on its own, so the effective limit is
  `limit × nodes`.
  """
  use GenServer

  @table __MODULE__
  @sweep_interval :timer.minutes(1)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Counts one hit for `key` and says whether it is within `limit` hits per
  `window_ms` milliseconds.

  Returns `{:allow, count}` with the hits counted so far in the window, or
  `{:deny, retry_after}` with the seconds left until the window ends.

  ## Examples

      iex> RephiWeb.RateLimiter.hit({:login, {127, 0, 0, 1}}, 10, 60_000)
      {:allow, 1}

  """
  @spec hit(term(), pos_integer(), pos_integer()) ::
          {:allow, pos_integer()} | {:deny, pos_integer()}
  def hit(key, limit, window_ms)
      when is_integer(limit) and limit > 0 and is_integer(window_ms) and window_ms > 0 do
    now = System.system_time(:millisecond)
    window = div(now, window_ms)
    expires_at = (window + 1) * window_ms

    count = :ets.update_counter(@table, {key, window}, {2, 1}, {{key, window}, 0, expires_at})

    if count > limit do
      {:deny, max(1, ceil((expires_at - now) / 1000))}
    else
      {:allow, count}
    end
  end

  @doc """
  Forgets every counter. Meant for tests.
  """
  @spec reset() :: :ok
  def reset do
    :ets.delete_all_objects(@table)
    :ok
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, write_concurrency: true])
    schedule_sweep()
    {:ok, nil}
  end

  @impl true
  def handle_info(:sweep, state) do
    now = System.system_time(:millisecond)
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    schedule_sweep()
    {:noreply, state}
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_interval)
end
