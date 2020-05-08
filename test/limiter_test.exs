defmodule LimiterTest do
  use ExUnit.Case
  doctest Limiter

  test "limiter ets is atomic" do
    name = "test1"
    Limiter.new(name, 2, 2)
    atomic_test(name)
  end

  test "limiter atomics is atomic" do
    name = "test2"
    Limiter.new(name, 2, 2, backend: :atomics)
    atomic_test(name)
  end

  defp atomic_test(name) do
    self = self()

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
