defmodule LimiterTest do
  use ExUnit.Case
  doctest Limiter

  defp test_ets(name, max, sleep, fun) do
    count = :ets.update_counter(:limiter_test, name, {2, 1}, {name, 0})

    if count <= max do
      fun.({:ok, count})
      Process.sleep(sleep)
    else
      fun.(:fail)
    end
  after
    :ets.update_counter(:limiter_test, name, {2, -1}, {name, 1})
  end

  test "limits with ets" do
    :ets.new(:limiter_test, [:public, :named_table])
    ets = "test"
    test = self()
    spawn_link(fn -> test_ets(ets, 2, 500, fn result -> send(test, result) end) end)
    spawn_link(fn -> test_ets(ets, 2, 750, fn result -> send(test, result) end) end)
    spawn_link(fn -> test_ets(ets, 2, 500, fn result -> send(test, result) end) end)
    assert_receive {:ok, 1}
    assert_receive {:ok, 2}
    assert_receive :fail
    Process.sleep(500)
    spawn_link(fn -> test_ets(ets, 2, 500, fn result -> send(test, result) end) end)
    assert_receive {:ok, 2}
  end

  test "limiter" do
    name = "test1"
    self = self()
    Limiter.set(name, 2, 2)

    sleepy = fn sleep ->
      case Limiter.limit(name, fn ->
             send(self, :ok)
             Process.sleep(sleep)
             :ok
           end) do
        :ok -> :ok
        other -> send(self, other)
      end
    end

    spawn_link(fn -> sleepy.(500) end)
    spawn_link(fn -> sleepy.(500) end)
    spawn_link(fn -> sleepy.(500) end)
    spawn_link(fn -> sleepy.(500) end)
    spawn_link(fn -> sleepy.(500) end)
    assert_receive :ok, 2000
    assert_receive :ok, 2000
    assert_receive {:error, :overload}, 2000
    assert_receive :ok, 2000
    assert_receive :ok, 2000
  end
end
