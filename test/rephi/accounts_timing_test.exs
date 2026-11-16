defmodule Rephi.AccountsTimingTest do
  @moduledoc """
  A login with an unknown email must cost about as much as one with a wrong
  password, or timing reveals registered emails. Raises the bcrypt cost tests lower.
  """
  use Rephi.DataCase, async: false

  import Rephi.AuthTestHelpers

  alias Rephi.Accounts

  @log_rounds 10
  @samples 5

  setup do
    put_app_env(:bcrypt_elixir, :log_rounds, @log_rounds)
    :ok
  end

  defp median_ms(fun) do
    times =
      for _ <- 1..@samples do
        {microseconds, _result} = :timer.tc(fun)
        microseconds / 1000
      end

    times |> Enum.sort() |> Enum.at(div(@samples, 2))
  end

  test "an unknown email spends the time of a password check" do
    create_user(%{email: "timing@example.com"})

    known =
      median_ms(fn -> Accounts.authenticate_user("timing@example.com", "wrong-password") end)

    unknown =
      median_ms(fn -> Accounts.authenticate_user("nobody@example.com", "wrong-password") end)

    assert unknown > known * 0.5,
           "unknown email took #{unknown} ms, known email #{known} ms"
  end
end
