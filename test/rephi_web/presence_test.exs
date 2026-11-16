defmodule RephiWeb.PresenceTest do
  use ExUnit.Case, async: true

  alias RephiWeb.Presence

  setup do
    %{topic: "presence_test:#{System.unique_integer([:positive])}"}
  end

  defp connection(topic, key) do
    test = self()

    pid =
      spawn_link(fn ->
        {:ok, _ref} = Presence.track(self(), topic, key, %{user_id: key})
        send(test, {:tracked, self()})

        receive do
          :leave -> :ok
        end
      end)

    assert_receive {:tracked, ^pid}
    pid
  end

  test "online_counts/1 counts distinct keys and every connection", %{topic: topic} do
    assert Presence.online_counts(topic) == %{online_users: 0, connections: 0}

    first = connection(topic, "1")
    connection(topic, "1")
    connection(topic, "2")

    assert Presence.online_counts(topic) == %{online_users: 2, connections: 3}

    ref = Process.monitor(first)
    send(first, :leave)
    assert_receive {:DOWN, ^ref, :process, _, _}

    wait_until(fn -> Presence.online_counts(topic).connections == 2 end)
    assert Presence.online_counts(topic) == %{online_users: 2, connections: 2}
  end

  test "online_counts/0 reads the lobby" do
    assert %{online_users: users, connections: connections} = Presence.online_counts()
    assert connections >= users
  end

  defp wait_until(fun, tries \\ 50) do
    cond do
      fun.() -> :ok
      tries == 0 -> flunk("condition never met")
      true -> Process.sleep(10) && wait_until(fun, tries - 1)
    end
  end
end
