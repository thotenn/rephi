defmodule RephiWeb.RateLimiter do
  @moduledoc """
  Fixed-window request counter in an ETS table, counted in the caller with atomic
  updates; the process only owns the table and sweeps expired entries. Per node
  and in memory.
  """
  use GenServer

  @table __MODULE__
  @sweep_interval :timer.minutes(1)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Counts one hit for `key`: `{:allow, count}` within `limit` hits per `window_ms`,
  or `{:deny, retry_after_seconds}`.
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
